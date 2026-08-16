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
rm -f /tmp/stage03-hostnames.txt
for _ in 1 2 3 4 5 6 7 8; do
  response="$(curl -fsS -H "Host: api.localhost" http://localhost:8080/api/items)"
  echo "$response" | grep -E '"hostname"|"instance"'
  echo "$response" | sed -n 's/.*"hostname":"\([^"]*\)".*/\1/p' >> /tmp/stage03-hostnames.txt
done
distinct_hosts="$(sort -u /tmp/stage03-hostnames.txt | wc -l | tr -d ' ')"
if [ "$distinct_hosts" -lt 2 ]; then
  echo "Expected requests to hit at least two different API containers." >&2
  exit 1
fi

echo "Checking Traefik loaded the API service..."
curl -fsS http://localhost:8081/api/http/services | grep -q '"api@file"'

echo "Stage 03 checks passed."
