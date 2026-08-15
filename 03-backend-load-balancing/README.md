# 03 - Backend load balancing

This stage keeps Redis and MySQL, then runs two API replicas behind Traefik.

Traefik routes to both scaled API containers from `traefik/dynamic/routes.yml`. The `--scale api=2` command creates the two expected container targets.

## Run

```bash
docker compose up -d --build --scale api=2
```

## Test

```bash
./scripts/check.sh
```

Manual check:

```bash
for i in {1..10}; do
  curl -H 'Host: api.localhost' http://localhost:8080/api/items
done
```

Look at the `hostname` value in responses. It should alternate between the two API containers over multiple requests.

Dashboard:

```bash
open http://localhost:8081/dashboard/
```

## Stop

```bash
docker compose down -v
```
