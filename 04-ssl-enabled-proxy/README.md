# 04 - SSL-enabled proxy

This stage upgrades Traefik to HTTPS.

Local laptop mode:

- Uses a generated self-signed certificate.
- Listens on `https://localhost:8443`.
- Redirects HTTP on `localhost:8080` to HTTPS.

Production domain mode:

- Traefik has an ACME resolver named `letsencrypt`.
- Add `compose.acme.yml` to attach that resolver to the routers.
- Traefik stores ACME state in the `letsencrypt` volume and renews certificates automatically.

## Run locally

```bash
./scripts/generate-local-certs.sh
docker compose up -d --build --scale api=2
```

## Test locally

```bash
./scripts/check.sh
```

Manual checks:

```bash
curl -k -H 'Host: app.localhost' https://localhost:8443/
curl -k -H 'Host: api.localhost' https://localhost:8443/api/items
open http://localhost:8081/dashboard/
```

## Production ACME example

Set real DNS first. Edit `traefik/dynamic/routes.acme.yml` so the `Host(...)` rules use your real front-end and API domains. Then run:

```bash
export ACME_EMAIL=ops@example.com
docker compose -f compose.yml -f compose.acme.yml up -d --build --scale api=2
```

For real ACME HTTP-01 validation, public ports `80` and `443` must reach this Docker host.

## Stop

```bash
docker compose down -v
```
