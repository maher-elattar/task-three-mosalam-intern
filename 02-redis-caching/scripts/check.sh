#!/usr/bin/env sh
# Smoke test for Redis caching.
# First request should read MySQL. Second request should be served from Redis.

set -eu

wait_for_traefik_docker_routes() {
  attempt=0
  while [ "$attempt" -lt 30 ]; do
    if curl -fsS http://localhost:8081/api/http/routers 2>/dev/null | grep -q '"backend-api@docker"' \
      && curl -fsS http://localhost:8081/api/http/routers 2>/dev/null | grep -q '"frontend@docker"'; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  echo "Traefik did not load the expected Docker-discovered routers." >&2
  curl -fsS http://localhost:8081/api/http/routers || true
  exit 1
}

wait_for_traefik_docker_routes

echo "Clearing cache..."
curl -fsS -X POST -H "Host: api.localhost" http://localhost:8080/api/cache/clear >/dev/null

echo "Checking MySQL-backed response..."
curl -fsS -H "Host: api.localhost" http://localhost:8080/api/items | grep -q '"source":"mysql"'

echo "Checking Redis-backed response..."
curl -fsS -H "Host: api.localhost" http://localhost:8080/api/items | grep -q '"source":"redis-cache"'

echo "Checking Redis key count..."
redis_keys="$(docker compose exec -T redis redis-cli DBSIZE | tr -d '\r')"
echo "$redis_keys"
if [ "$redis_keys" -lt 1 ]; then
  echo "Expected at least one Redis cache key." >&2
  exit 1
fi

echo "Checking that Redis and MySQL do not publish host ports..."
redis_ports="$(docker inspect "$(docker compose ps -q redis)" --format '{{json .NetworkSettings.Ports}}')"
mysql_ports="$(docker inspect "$(docker compose ps -q mysql)" --format '{{json .NetworkSettings.Ports}}')"
if echo "$redis_ports" | grep -q '"HostPort"'; then
  echo "Redis must not publish a host port in this stage." >&2
  exit 1
fi
if echo "$mysql_ports" | grep -q '"HostPort"'; then
  echo "MySQL must not publish a host port in this stage." >&2
  exit 1
fi

echo "Checking Redis is private-network only..."
redis_networks="$(docker inspect "$(docker compose ps -q redis)" --format '{{json .NetworkSettings.Networks}}')"
echo "$redis_networks" | grep -q "task03_stage02_private"
if echo "$redis_networks" | grep -q "task03_stage02_public"; then
  echo "Redis must stay off the public network." >&2
  exit 1
fi

echo "Checking Traefik Docker discovery..."
curl -fsS http://localhost:8081/api/http/routers | grep -q '"backend-api@docker"'
curl -fsS http://localhost:8081/api/http/routers | grep -q '"frontend@docker"'

echo "Stage 02 checks passed."
