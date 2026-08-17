import json
import logging
import os
import socket
import time
from contextlib import contextmanager

import pymysql
import redis
from flask import Flask, Response, jsonify, request
from prometheus_client import Counter, Histogram, generate_latest


app = Flask(__name__)


# Environment variables make the same image usable in every stage.
INSTANCE_NAME = os.getenv("INSTANCE_NAME", socket.gethostname())
MYSQL_HOST = os.getenv("MYSQL_HOST", "mysql")
MYSQL_PORT = int(os.getenv("MYSQL_PORT", "3306"))
MYSQL_DATABASE = os.getenv("MYSQL_DATABASE", "appdb")
MYSQL_USER = os.getenv("MYSQL_USER", "appuser")
MYSQL_PASSWORD = os.getenv("MYSQL_PASSWORD", "apppass")
REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
CACHE_ENABLED = os.getenv("CACHE_ENABLED", "false").lower() == "true"
CACHE_TTL_SECONDS = int(os.getenv("CACHE_TTL_SECONDS", "30"))
API_KEY = os.getenv("API_KEY", "lab-secret-key")
BLOCKED_IPS = {
    ip.strip()
    for ip in os.getenv("BLOCKED_IPS", "").split(",")
    if ip.strip()
}


# Structured stdout logs are easy for Promtail/Loki to parse and search.
logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger("sample-api")


REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests served by the sample API.",
    ["method", "endpoint", "status"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds.",
    ["method", "endpoint"],
    buckets=(0.01, 0.05, 0.1, 0.25, 0.5, 1, 2, 5),
)


def log_event(event, **fields):
    payload = {
        "event": event,
        "instance": INSTANCE_NAME,
        "hostname": socket.gethostname(),
        **fields,
    }
    logger.info(json.dumps(payload, sort_keys=True))


@contextmanager
def mysql_connection():
    # Connections are opened per request to keep the example explicit.
    # A production API would normally use a pool.
    connection = pymysql.connect(
        host=MYSQL_HOST,
        port=MYSQL_PORT,
        user=MYSQL_USER,
        password=MYSQL_PASSWORD,
        database=MYSQL_DATABASE,
        connect_timeout=3,
        read_timeout=5,
        write_timeout=5,
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
    )
    try:
        yield connection
    finally:
        connection.close()


def redis_client():
    if not CACHE_ENABLED:
        return None
    return redis.Redis(
        host=REDIS_HOST,
        port=REDIS_PORT,
        socket_connect_timeout=2,
        socket_timeout=2,
        decode_responses=True,
    )


def normalize_products(rows):
    # PyMySQL returns DECIMAL as Decimal objects; convert them before jsonify/cache.
    return [
        {
            "id": int(row["id"]),
            "name": row["name"],
            "price": float(row["price"]),
        }
        for row in rows
    ]


def client_ip():
    forwarded = request.headers.get("X-Forwarded-For", "")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.remote_addr or "unknown"


@app.before_request
def before_request():
    request._started_at = time.perf_counter()


@app.after_request
def after_request(response):
    endpoint = request.path
    duration = time.perf_counter() - getattr(request, "_started_at", time.perf_counter())
    REQUESTS.labels(request.method, endpoint, str(response.status_code)).inc()
    REQUEST_LATENCY.labels(request.method, endpoint).observe(duration)
    log_event(
        "request",
        method=request.method,
        path=endpoint,
        status=response.status_code,
        duration_ms=round(duration * 1000, 2),
        client_ip=client_ip(),
    )
    return response


@app.get("/health")
def health():
    return jsonify(
        status="ok",
        instance=INSTANCE_NAME,
        hostname=socket.gethostname(),
    )


@app.get("/ready")
def ready():
    checks = {"mysql": "unknown", "redis": "disabled"}
    with mysql_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1 AS ok")
            checks["mysql"] = "ok" if cursor.fetchone()["ok"] == 1 else "bad"

    cache = redis_client()
    if cache:
        cache.ping()
        checks["redis"] = "ok"

    return jsonify(status="ready", checks=checks)


@app.get("/api/items")
def items():
    cache_key = "catalog:v1"
    cache = redis_client()

    if cache:
        cached = cache.get(cache_key)
        if cached:
            log_event("cache_hit", key=cache_key)
            return jsonify(
                source="redis-cache",
                cache="hit",
                instance=INSTANCE_NAME,
                hostname=socket.gethostname(),
                products=json.loads(cached),
            )

    with mysql_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT id, name, price FROM products ORDER BY id")
            products = normalize_products(cursor.fetchall())

    if cache:
        cache.setex(cache_key, CACHE_TTL_SECONDS, json.dumps(products, default=str))
        log_event("cache_miss_then_store", key=cache_key, ttl_seconds=CACHE_TTL_SECONDS)

    return jsonify(
        source="mysql",
        cache="miss" if cache else "disabled",
        instance=INSTANCE_NAME,
        hostname=socket.gethostname(),
        products=products,
    )


@app.post("/api/cache/clear")
def clear_cache():
    cache = redis_client()
    if not cache:
        return jsonify(status="cache-disabled")
    cache.delete("catalog:v1")
    return jsonify(status="cache-cleared")


@app.get("/api/slow")
def slow():
    # This endpoint is used later to demonstrate latency alerts.
    delay_ms = min(int(request.args.get("delay_ms", "750")), 5000)
    time.sleep(delay_ms / 1000)
    return jsonify(status="slow-response", delay_ms=delay_ms, instance=INSTANCE_NAME)


@app.get("/auth")
def forward_auth():
    # Traefik calls this endpoint before proxying API requests in the security stage.
    # Keeping the check here lets the proxy enforce API keys and IP blocks centrally.
    ip = client_ip()
    if ip in BLOCKED_IPS:
        log_event("blocked_ip", client_ip=ip)
        return jsonify(error="blocked ip"), 403

    if request.headers.get("X-API-Key") != API_KEY:
        log_event("missing_or_invalid_api_key", client_ip=ip)
        return jsonify(error="missing or invalid api key"), 401

    response = Response(status=200)
    response.headers["X-Authenticated-By"] = "traefik-forward-auth"
    return response


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), mimetype="text/plain; version=0.0.4")


@app.errorhandler(Exception)
def handle_error(exc):
    log_event("error", error=str(exc), path=request.path)
    return jsonify(error=str(exc), instance=INSTANCE_NAME), 500
