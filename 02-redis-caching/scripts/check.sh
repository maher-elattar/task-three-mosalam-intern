#!/usr/bin/env sh
# Smoke test for Redis caching.
# First request should read MySQL. Second request should be served from Redis.

set -eu

echo "Clearing cache..."
curl -fsS -X POST -H "Host: api.localhost" http://localhost:8080/api/cache/clear >/dev/null

echo "Checking MySQL-backed response..."
curl -fsS -H "Host: api.localhost" http://localhost:8080/api/items | grep -q '"source":"mysql"'

echo "Checking Redis-backed response..."
curl -fsS -H "Host: api.localhost" http://localhost:8080/api/items | grep -q '"source":"redis-cache"'

echo "Checking Redis key count..."
docker compose exec -T redis redis-cli DBSIZE

echo "Stage 02 checks passed."

