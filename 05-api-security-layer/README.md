# 05 - API security layer

This stage adds security controls at the proxy layer.

Implemented controls:

- API key check with Traefik `forwardAuth`.
- IP block list checked before the API receives traffic.
- Rate limiting per source IP.
- Security headers such as HSTS and `X-Content-Type-Options`.

The API itself still has no public port. Clients must pass through Traefik.

## Run

```bash
./scripts/generate-local-certs.sh
docker compose up -d --build --scale api=2
```

## Test

```bash
./scripts/check.sh
```

Manual checks:

```bash
# Rejected: no API key.
curl -k -i -H 'Host: api.localhost' https://localhost:8443/api/items

# Accepted.
curl -k -H 'Host: api.localhost' \
  -H 'X-API-Key: intern-secret-key' \
  https://localhost:8443/api/items

# Rejected: blocked source IP demonstration.
curl -k -i -H 'Host: api.localhost' \
  -H 'X-API-Key: intern-secret-key' \
  -H 'X-Forwarded-For: 203.0.113.10' \
  https://localhost:8443/api/items
```

## Stop

```bash
docker compose down -v
```

