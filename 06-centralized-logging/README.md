# 06 - Centralized logging

This stage adds central logging.

Components:

- Loki stores logs.
- Promtail discovers this Compose project's containers and ships Docker logs to Loki.
- Grafana is preconfigured with Loki as the default datasource.

Why Loki:

- It is lightweight for Docker Compose labs.
- It indexes labels instead of full log text, so it is cheaper to run than full-text indexing systems.
- It integrates directly with Grafana.

## Run

```bash
./scripts/generate-local-certs.sh
docker compose up -d --build --scale api=2
```

## Test

```bash
./scripts/check.sh
```

Manual log query:

```bash
curl -k -H 'Host: api.localhost' -H 'X-API-Key: intern-secret-key' https://localhost:8443/api/items
curl -G http://localhost:3100/loki/api/v1/series \
  --data-urlencode 'match[]={project="task03_stage06_logging"}'
```

Grafana:

```bash
open http://localhost:3300
```

Login is `admin` / `admin`, and anonymous admin access is enabled for the lab.

## Stop

```bash
docker compose down -v
```

