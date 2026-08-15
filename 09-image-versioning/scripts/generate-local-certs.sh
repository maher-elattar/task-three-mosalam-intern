#!/usr/bin/env sh
# Generates a local self-signed certificate for laptop testing.
# Production certificates are handled by Traefik ACME in compose.acme.yml.

set -eu

mkdir -p certs

if [ -f certs/local.crt ] && [ -f certs/local.key ]; then
  echo "Local certificate already exists."
  exit 0
fi

openssl req -x509 -nodes -newkey rsa:2048 \
  -days "${CERT_DAYS:-30}" \
  -keyout certs/local.key \
  -out certs/local.crt \
  -subj "/CN=app.localhost" \
  -addext "subjectAltName=DNS:app.localhost,DNS:api.localhost,DNS:traefik.localhost,DNS:localhost,IP:127.0.0.1"

chmod 600 certs/local.key
echo "Generated certs/local.crt and certs/local.key"

