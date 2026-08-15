# 11 - Load testing

This stage adds load testing with k6 while keeping the previous security, logging, backup, monitoring, alerting, image-versioning, and database-failover layers.

Components:

- k6 sends HTTPS traffic through Traefik.
- The load test includes normal API reads, occasional cache clears, and occasional slow requests.
- Prometheus, Alertmanager, Grafana, Loki, Traefik, API replicas, MySQL, Redis, and HAProxy can be watched during the run.

Rate-limit note:

The API rate limit is higher in this stage than in stage 05. The goal here is to load the system, not to stop most requests at the proxy.

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

Manual failover test:

```bash
docker compose exec redis redis-cli DEL catalog:v1
curl -k -H 'Host: api.localhost' -H 'X-API-Key: intern-secret-key' https://localhost:8443/api/items

docker compose stop mysql-primary
sleep 12
docker compose exec redis redis-cli DEL catalog:v1
curl -k -H 'Host: api.localhost' -H 'X-API-Key: intern-secret-key' https://localhost:8443/api/items
docker compose start mysql-primary
```

HAProxy stats:

```bash
open http://localhost:8404/stats
```

Manual logging check:

```bash
curl -k -H 'Host: api.localhost' -H 'X-API-Key: intern-secret-key' https://localhost:8443/api/items
curl -G http://localhost:3100/loki/api/v1/series \
  --data-urlencode 'match[]={project="task03_stage11_loadtest"}'
```

Run the load test:

```bash
docker compose run --rm k6 run /scripts/load-test.js
```

Shorter lecture run:

```bash
docker compose run --rm -e K6_VUS=10 -e K6_DURATION=15s k6 run /scripts/load-test.js
```

Watch during the test:

```bash
open http://localhost:8081/dashboard/
open http://localhost:9090
open http://localhost:9093
open http://localhost:3300
open http://localhost:8404/stats
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
