# 10 - Database failover

This stage adds simple database failover while keeping the previous security, logging, backup, monitoring, alerting, and image-versioning layers.

Components:

- `mysql-primary` is the normal database target.
- `mysql-standby` is marked as the backup target.
- `db-proxy` uses HAProxy TCP checks and switches to standby when primary fails.
- The API and backup worker connect to `db-proxy`, not directly to a MySQL container.

Important limitation:

This is routing failover, not full database high availability. The two MySQL containers are seeded with the same schema, but there is no replication. A production design would use MySQL replication, InnoDB Cluster, Galera, or a managed database service.

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
  --data-urlencode 'match[]={project="task03_stage10_failover"}'
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
