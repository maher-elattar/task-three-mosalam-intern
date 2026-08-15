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

echo "Sending a small burst to demonstrate rate limit behavior..."
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  curl -k -s -o /dev/null -w "%{http_code}\n" -H "Host: api.localhost" -H "X-API-Key: intern-secret-key" https://localhost:8443/api/items
done | sort | uniq -c

echo "Stage 05 checks passed."

