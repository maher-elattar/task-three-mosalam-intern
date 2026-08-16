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

echo "Checking that API and MySQL do not publish host ports..."
api_ports="$(docker inspect "$(docker compose ps -q api)" --format '{{json .NetworkSettings.Ports}}')"
mysql_ports="$(docker inspect "$(docker compose ps -q mysql)" --format '{{json .NetworkSettings.Ports}}')"
if echo "$api_ports" | grep -q '"HostPort"'; then
  echo "API must not publish a host port in this stage." >&2
  exit 1
fi
if echo "$mysql_ports" | grep -q '"HostPort"'; then
  echo "MySQL must not publish a host port in this stage." >&2
  exit 1
fi

echo "Checking Docker network isolation..."
api_networks="$(docker inspect "$(docker compose ps -q api)" --format '{{json .NetworkSettings.Networks}}')"
mysql_networks="$(docker inspect "$(docker compose ps -q mysql)" --format '{{json .NetworkSettings.Networks}}')"
front_networks="$(docker inspect "$(docker compose ps -q front)" --format '{{json .NetworkSettings.Networks}}')"
traefik_networks="$(docker inspect "$(docker compose ps -q traefik)" --format '{{json .NetworkSettings.Networks}}')"

echo "$api_networks" | grep -q "task03_stage01_private"
echo "$mysql_networks" | grep -q "task03_stage01_private"
echo "$front_networks" | grep -q "task03_stage01_public"
echo "$traefik_networks" | grep -q "task03_stage01_public"
echo "$traefik_networks" | grep -q "task03_stage01_private"

if echo "$api_networks" | grep -q "task03_stage01_public"; then
  echo "API must stay off the public network." >&2
  exit 1
fi
if echo "$mysql_networks" | grep -q "task03_stage01_public"; then
  echo "MySQL must stay off the public network." >&2
  exit 1
fi

echo "Checking that MySQL is reachable from inside the private network..."
docker compose exec -T mysql mysql -uappuser -papppass appdb -e "SELECT COUNT(*) AS products FROM products;"

echo "Stage 01 checks passed."
