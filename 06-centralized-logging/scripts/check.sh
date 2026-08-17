#!/usr/bin/env sh
# Smoke test for centralized logging.

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

echo "Generating API logs..."
curl -kfsS -H "Host: api.localhost" -H "X-API-Key: lab-secret-key" https://localhost:8443/api/items >/dev/null

echo "Checking Loki readiness..."
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  if curl -fsS http://localhost:3100/ready >/dev/null; then
    break
  fi
  sleep 2
done
curl -fsS http://localhost:3100/ready >/dev/null

echo "Checking Grafana health..."
curl -fsS http://localhost:3300/api/health | grep -q "ok"

echo "Checking Grafana Loki datasource provisioning..."
curl -fsS http://localhost:3300/api/datasources | grep -q "Loki"

echo "Waiting briefly for Promtail to ship logs..."
sleep 8

echo "Checking Loki labels include the Compose project..."
curl -fsS -G http://localhost:3100/loki/api/v1/series \
  --data-urlencode 'match[]={project="task03_stage06_logging"}' | grep -q "task03_stage06_logging"

echo "Checking Loki returns log streams for this project..."
curl -fsS -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={project="task03_stage06_logging"}' \
  --data-urlencode 'limit=10' | grep -q '"resultType":"streams"'

echo "Checking ACME overlay renders valid Compose config..."
docker compose -f compose.yml -f compose.acme.yml config -q

echo "Checking Traefik Docker discovery..."
curl -fsS http://localhost:8081/api/http/routers | grep -q '"backend-api@docker"'
curl -fsS http://localhost:8081/api/http/routers | grep -q '"frontend@docker"'

echo "Stage 06 checks passed."
