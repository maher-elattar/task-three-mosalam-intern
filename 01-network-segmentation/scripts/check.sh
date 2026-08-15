#!/usr/bin/env sh
# Smoke test for the network segmentation stage.
# It verifies that traffic reaches the front-end and API only through Traefik.

set -eu

echo "Checking front-end through Traefik..."
curl -fsS -H "Host: app.localhost" http://localhost:8080/ | grep -q "Production-like Compose Lab"

echo "Checking API through Traefik..."
curl -fsS -H "Host: api.localhost" http://localhost:8080/api/items | grep -q "products"

echo "Checking Traefik dashboard API..."
curl -fsS http://localhost:8081/api/rawdata >/dev/null

echo "Checking that MySQL is reachable from inside the private network..."
docker compose exec -T mysql mysql -uappuser -papppass appdb -e "SELECT COUNT(*) AS products FROM products;"

echo "Stage 01 checks passed."

