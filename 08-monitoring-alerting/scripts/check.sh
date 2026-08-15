#!/usr/bin/env sh
# Smoke test for monitoring and alerting.

set -eu

echo "Generating API logs..."
curl -kfsS -H "Host: api.localhost" -H "X-API-Key: intern-secret-key" https://localhost:8443/api/items >/dev/null

echo "Checking that the backup worker created a timestamped dump..."
docker compose exec -T backup sh -lc 'ls -1 /backups/appdb-*.sql | tail -1'

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

echo "Checking Prometheus readiness..."
curl -fsS http://localhost:9090/-/ready >/dev/null

echo "Checking Alertmanager readiness..."
curl -fsS http://localhost:9093/-/ready >/dev/null

echo "Checking blackbox HTTPS probe..."
curl -fsS "http://localhost:9115/probe?module=https_2xx_insecure&target=https://api.localhost:8443/api/items" | grep -q "probe_ssl_earliest_cert_expiry"

echo "Checking alert rules are loaded..."
curl -fsS http://localhost:9090/api/v1/rules | grep -q "ApiP95LatencyHigh"

echo "Waiting briefly for Promtail to ship logs..."
sleep 8

echo "Checking Loki labels include the Compose project..."
curl -fsS -G http://localhost:3100/loki/api/v1/series \
  --data-urlencode 'match[]={project="task03_stage08_alerting"}' | grep -q "task03_stage08_alerting"

echo "Stage 08 checks passed."
