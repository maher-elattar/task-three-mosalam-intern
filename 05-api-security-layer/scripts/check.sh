#!/usr/bin/env sh
# Smoke test for proxy security controls.

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

echo "Checking that missing API key is rejected..."
status="$(curl -k -s -o /dev/null -w "%{http_code}" -H "Host: api.localhost" https://localhost:8443/api/items)"
if [ "$status" != "401" ]; then
  echo "Expected 401 without API key, got $status" >&2
  exit 1
fi

echo "Checking that blocked IP is rejected by forward auth..."
status="$(curl -k -s -o /dev/null -w "%{http_code}" -H "Host: api.localhost" -H "X-API-Key: lab-secret-key" -H "X-Forwarded-For: 203.0.113.10" https://localhost:8443/api/items)"
if [ "$status" != "403" ]; then
  echo "Expected 403 for blocked IP, got $status" >&2
  exit 1
fi

echo "Checking that valid API key is accepted..."
curl -kfsS -H "Host: api.localhost" -H "X-API-Key: lab-secret-key" https://localhost:8443/api/items | grep -q "products"

echo "Checking proxy security headers..."
curl -kfsS -D /tmp/stage05-headers.txt -o /dev/null -H "Host: api.localhost" -H "X-API-Key: lab-secret-key" https://localhost:8443/api/items
grep -qi "strict-transport-security" /tmp/stage05-headers.txt
grep -qi "x-content-type-options: nosniff" /tmp/stage05-headers.txt

echo "Sending a small burst to demonstrate rate limit behavior..."
rm -f /tmp/stage05-statuses.txt
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25; do
  curl -k -s -o /dev/null -w "%{http_code}\n" -H "Host: api.localhost" -H "X-API-Key: lab-secret-key" https://localhost:8443/api/items
done > /tmp/stage05-statuses.txt
sort /tmp/stage05-statuses.txt | uniq -c
grep -q '^429$' /tmp/stage05-statuses.txt

echo "Checking Traefik middleware configuration is loaded..."
curl -fsS http://localhost:8081/api/http/middlewares | grep -q "api-rate-limit@docker"
curl -fsS http://localhost:8081/api/http/middlewares | grep -q "api-key-auth@docker"

echo "Checking ACME overlay renders valid Compose config..."
docker compose -f compose.yml -f compose.acme.yml config -q

echo "Checking Traefik Docker discovery..."
curl -fsS http://localhost:8081/api/http/routers | grep -q '"backend-api@docker"'
curl -fsS http://localhost:8081/api/http/routers | grep -q '"frontend@docker"'

echo "Stage 05 checks passed."
