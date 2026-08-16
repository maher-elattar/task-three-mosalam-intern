#!/usr/bin/env sh
# Smoke test for database backups.

set -eu

echo "Generating API logs..."
curl -kfsS -H "Host: api.localhost" -H "X-API-Key: intern-secret-key" https://localhost:8443/api/items >/dev/null

echo "Checking that the backup worker created a timestamped dump..."
docker compose exec -T backup sh -lc 'latest="$(ls -1 /backups/appdb-*.sql | tail -1)"; echo "$latest"; test -s "$latest"; grep -q "CREATE TABLE" "$latest"; grep -q "products" "$latest"'

echo "Checking backup volume exists separately from MySQL runtime data..."
docker volume inspect task03_stage07_backups_db_backups >/dev/null

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

echo "Waiting briefly for Promtail to ship logs..."
sleep 8

echo "Checking Loki labels include the Compose project..."
curl -fsS -G http://localhost:3100/loki/api/v1/series \
  --data-urlencode 'match[]={project="task03_stage07_backups"}' | grep -q "task03_stage07_backups"

echo "Checking ACME overlay renders valid Compose config..."
docker compose -f compose.yml -f compose.acme.yml config -q

echo "Stage 07 checks passed."
