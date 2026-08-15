# 08 - Monitoring and alerting

This stage adds Prometheus monitoring and Alertmanager alerting while keeping the previous security, logging, and backup layers.

Components:

- Prometheus scrapes Traefik, API replicas, MySQL, Redis, cAdvisor, node-exporter, and blackbox exporter.
- Alertmanager receives Prometheus alerts.
- Blackbox exporter probes HTTPS and exposes certificate expiry metrics.
- Grafana has Loki and Prometheus datasources.
- Backup worker still creates timestamped MySQL dumps.

Alerts included:

- API p95 latency high.
- MySQL connection count high.
- Monitored target down.
- Host memory almost full.
- TLS certificate expires soon.

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
  --data-urlencode 'match[]={project="task03_stage08_alerting"}'
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
