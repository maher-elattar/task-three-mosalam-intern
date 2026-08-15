#!/usr/bin/env sh
# Smoke test for HTTPS, HTTP-to-HTTPS redirect, and Traefik routing.

set -eu

echo "Checking HTTPS front-end..."
curl -kfsS -H "Host: app.localhost" https://localhost:8443/ | grep -q "Production-like Compose Lab"

echo "Checking HTTPS API..."
curl -kfsS -H "Host: api.localhost" https://localhost:8443/api/items | grep -q "products"

echo "Checking HTTP redirects to HTTPS..."
status="$(curl -s -o /dev/null -w "%{http_code}" -H "Host: app.localhost" http://localhost:8080/)"
if [ "$status" != "301" ] && [ "$status" != "308" ]; then
  echo "Expected HTTP redirect, got $status" >&2
  exit 1
fi

echo "Checking local certificate file exists..."
test -s certs/local.crt

echo "Stage 04 checks passed."

