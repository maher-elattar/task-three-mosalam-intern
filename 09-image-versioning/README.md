# 09 - Image versioning

This stage adds explicit image versioning while keeping the previous security, logging, backup, monitoring, and alerting layers.

Components:

- `front:v2` is built from `front/Dockerfile`.
- `api:v2` is built from `api/Dockerfile`.
- `db:v2` is built from `db/Dockerfile` and includes the seed SQL.
- Third-party images keep pinned upstream tags such as `traefik:v3.1` and `redis:7.4-alpine`.

Versioning rule for interns:

- Any application or schema change must create a new immutable tag.
- Example: change the API, then move from `api:v2` to `api:v3`.
- Do not reuse an existing tag for a different build in a real registry.

## Run

```bash
./scripts/generate-local-certs.sh
docker compose up -d --build --scale api=2
```

## Test

```bash
./scripts/check.sh
```

Manual backup check:

```bash
docker compose exec backup ls -lh /backups
```

Image tag check:

```bash
docker image inspect front:v2 api:v2 db:v2
```

Manual logging check:

```bash
curl -k -H 'Host: api.localhost' -H 'X-API-Key: intern-secret-key' https://localhost:8443/api/items
curl -G http://localhost:3100/loki/api/v1/series \
  --data-urlencode 'match[]={project="task03_stage09_versioning"}'
```

Prometheus and Alertmanager:

```bash
open http://localhost:9090
open http://localhost:9093
```

Trigger the API latency alert:

```bash
for i in {1..40}; do
  curl -k -H 'Host: api.localhost' \
    -H 'X-API-Key: intern-secret-key' \
    'https://localhost:8443/api/slow?delay_ms=900'
done
```

Grafana is available at `http://localhost:3300`.

## Stop

```bash
docker compose down -v
```
