# 07 - Database backups

This stage adds automated database backups while keeping the previous logging stack.

Components:

- Backup worker creates timestamped MySQL dumps.
- Backup files are stored in a separate `db_backups` Docker volume.
- Loki stores logs.
- Promtail discovers this Compose project's containers and ships Docker logs to Loki.
- Grafana is preconfigured with Loki as the default datasource.

Why a separate backup volume:

- It survives container replacement.
- It separates database runtime files from backup artifacts.
- It makes restore testing easier because backups are explicit SQL files.

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

Manual logging check:

```bash
curl -k -H 'Host: api.localhost' -H 'X-API-Key: intern-secret-key' https://localhost:8443/api/items
curl -G http://localhost:3100/loki/api/v1/series \
  --data-urlencode 'match[]={project="task03_stage07_backups"}'
```

Grafana is available at `http://localhost:3300`.

## Stop

```bash
docker compose down -v
```
