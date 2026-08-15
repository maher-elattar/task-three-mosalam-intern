# 01 - Network segmentation

This stage separates public and private traffic.

- `public` network: Traefik and the front-end.
- `private` network: API and MySQL.
- Traefik joins both networks and becomes the only path from the public side to the API.
- MySQL has no host port and cannot be reached directly from the laptop.

## Run

```bash
docker compose up -d --build
```

## Test

```bash
./scripts/check.sh
```

Manual checks:

```bash
curl -H 'Host: app.localhost' http://localhost:8080/
curl -H 'Host: api.localhost' http://localhost:8080/api/items
open http://localhost:8081/dashboard/
```

## Stop

```bash
docker compose down -v
```

`-v` removes the teaching database volume so the next run starts clean.

