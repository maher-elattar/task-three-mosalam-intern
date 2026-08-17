#!/usr/bin/env sh
# Smoke test for HTTPS, HTTP-to-HTTPS redirect, and Traefik routing.

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

echo "Checking HTTPS front-end..."
curl -kfsS -H "Host: app.localhost" https://localhost:8443/ | grep -q "Production-like Compose Lab"

echo "Checking HTTPS API..."
curl -kfsS -H "Host: api.localhost" https://localhost:8443/api/items | grep -q "products"

echo "Checking HTTP redirects to HTTPS..."
status="$(curl -s -o /dev/null -D /tmp/stage04-redirect-headers.txt -w "%{http_code}" -H "Host: app.localhost" http://localhost:8080/)"
if [ "$status" != "301" ] && [ "$status" != "308" ]; then
  echo "Expected HTTP redirect, got $status" >&2
  exit 1
fi
grep -qi "location: https://" /tmp/stage04-redirect-headers.txt

echo "Checking local certificate file exists..."
test -s certs/local.crt
openssl x509 -in certs/local.crt -noout -subject | grep -q "app.localhost"

echo "Checking ACME overlay renders valid Compose config..."
docker compose -f compose.yml -f compose.acme.yml config -q

echo "Checking Traefik Docker discovery..."
curl -fsS http://localhost:8081/api/http/routers | grep -q '"backend-api@docker"'
curl -fsS http://localhost:8081/api/http/routers | grep -q '"frontend@docker"'

echo "Stage 04 checks passed."
