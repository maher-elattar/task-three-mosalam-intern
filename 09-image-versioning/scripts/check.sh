#!/usr/bin/env sh
# Smoke test for image versioning.

set -eu

echo "Generating API logs..."
curl -kfsS -H "Host: api.localhost" -H "X-API-Key: intern-secret-key" https://localhost:8443/api/items >/dev/null

echo "Checking that the backup worker created a timestamped dump..."
docker compose exec -T backup sh -lc 'latest="$(ls -1 /backups/appdb-*.sql | tail -1)"; echo "$latest"; test -s "$latest"; grep -q "CREATE TABLE" "$latest"; grep -q "products" "$latest"'

echo "Checking custom image tags..."
docker image inspect front:v2 api:v2 db:v2 >/dev/null
docker compose config --images | grep -q '^front:v2$'
docker compose config --images | grep -q '^api:v2$'
docker compose config --images | grep -q '^db:v2$'

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

echo "Checking Prometheus target coverage..."
targets="$(curl -fsS http://localhost:9090/api/v1/targets)"
for job in prometheus traefik api mysql redis cadvisor node blackbox-ssl; do
  echo "$targets" | grep -q "\"job\":\"$job\""
done
echo "$targets" | grep -q '"health":"up"'

echo "Checking Alertmanager readiness..."
curl -fsS http://localhost:9093/-/ready >/dev/null

echo "Checking blackbox HTTPS probe..."
curl -fsS "http://localhost:9115/probe?module=https_2xx_insecure&target=https://api.localhost:8443/api/items" | grep -q "probe_ssl_earliest_cert_expiry"

echo "Checking alert rules are loaded..."
curl -fsS http://localhost:9090/api/v1/rules | grep -q "ApiP95LatencyHigh"
curl -fsS http://localhost:9090/api/v1/rules | grep -q "DatabaseConnectionsHigh"
curl -fsS http://localhost:9090/api/v1/rules | grep -q "SslCertificateExpiresSoon"

echo "Waiting briefly for Promtail to ship logs..."
sleep 8

echo "Checking Loki labels include the Compose project..."
curl -fsS -G http://localhost:3100/loki/api/v1/series \
  --data-urlencode 'match[]={project="task03_stage09_versioning"}' | grep -q "task03_stage09_versioning"

echo "Checking ACME overlay renders valid Compose config..."
docker compose -f compose.yml -f compose.acme.yml config -q

echo "Stage 09 checks passed."
