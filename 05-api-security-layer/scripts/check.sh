#!/usr/bin/env sh
# Smoke test for proxy security controls.

set -eu

echo "Checking that missing API key is rejected..."
status="$(curl -k -s -o /dev/null -w "%{http_code}" -H "Host: api.localhost" https://localhost:8443/api/items)"
if [ "$status" != "401" ]; then
  echo "Expected 401 without API key, got $status" >&2
  exit 1
fi

echo "Checking that blocked IP is rejected by forward auth..."
status="$(curl -k -s -o /dev/null -w "%{http_code}" -H "Host: api.localhost" -H "X-API-Key: intern-secret-key" -H "X-Forwarded-For: 203.0.113.10" https://localhost:8443/api/items)"
if [ "$status" != "403" ]; then
  echo "Expected 403 for blocked IP, got $status" >&2
  exit 1
fi

echo "Checking that valid API key is accepted..."
curl -kfsS -H "Host: api.localhost" -H "X-API-Key: intern-secret-key" https://localhost:8443/api/items | grep -q "products"

echo "Checking proxy security headers..."
curl -kfsS -D /tmp/stage05-headers.txt -o /dev/null -H "Host: api.localhost" -H "X-API-Key: intern-secret-key" https://localhost:8443/api/items
grep -qi "strict-transport-security" /tmp/stage05-headers.txt
grep -qi "x-content-type-options: nosniff" /tmp/stage05-headers.txt

echo "Sending a small burst to demonstrate rate limit behavior..."
rm -f /tmp/stage05-statuses.txt
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25; do
  curl -k -s -o /dev/null -w "%{http_code}\n" -H "Host: api.localhost" -H "X-API-Key: intern-secret-key" https://localhost:8443/api/items
done > /tmp/stage05-statuses.txt
sort /tmp/stage05-statuses.txt | uniq -c
grep -q '^429$' /tmp/stage05-statuses.txt

echo "Checking Traefik middleware configuration is loaded..."
curl -fsS http://localhost:8081/api/http/middlewares | grep -q "api-rate-limit@file"
curl -fsS http://localhost:8081/api/http/middlewares | grep -q "api-key-auth@file"

echo "Checking ACME overlay renders valid Compose config..."
docker compose -f compose.yml -f compose.acme.yml config -q

echo "Stage 05 checks passed."
