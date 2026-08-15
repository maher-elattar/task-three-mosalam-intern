# 02 - Redis caching

This stage adds Redis on the private network.

Request flow:

```text
client -> Traefik -> API -> Redis
                         -> MySQL only on cache miss
```

The API caches `/api/items` for 30 seconds. This demonstrates how a cache can reduce repeated reads against MySQL.

## Run

```bash
docker compose up -d --build
```

## Test

```bash
./scripts/check.sh
```

Manual cache check:

```bash
curl -X POST -H 'Host: api.localhost' http://localhost:8080/api/cache/clear
curl -H 'Host: api.localhost' http://localhost:8080/api/items
curl -H 'Host: api.localhost' http://localhost:8080/api/items
```

The first `GET` should show `"source":"mysql"`. The second should show `"source":"redis-cache"`.

## Stop

```bash
docker compose down -v
```

