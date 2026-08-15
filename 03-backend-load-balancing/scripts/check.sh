#!/usr/bin/env sh
# Smoke test for Traefik load balancing.
# Start this stage with: docker compose up -d --build --scale api=2

set -eu

api_count="$(docker compose ps -q api | wc -l | tr -d ' ')"
if [ "$api_count" -lt 2 ]; then
  echo "Expected at least two API containers. Run: docker compose up -d --build --scale api=2" >&2
  exit 1
fi

echo "Sending repeated requests through Traefik..."
for _ in 1 2 3 4 5 6 7 8; do
  curl -fsS -H "Host: api.localhost" http://localhost:8080/api/items | grep -E '"hostname"|"instance"'
done

echo "Checking Traefik loaded the API service..."
curl -fsS http://localhost:8081/api/http/services | grep -q '"api@file"'

echo "Stage 03 checks passed."
