# 01 - Network segmentation

This stage separates public and private traffic.

- `public` network: Traefik and the front-end.
- `private` network: API and MySQL.
- Traefik joins both networks and becomes the only bridge from public traffic to the API.
- The API and MySQL publish no host ports.

## Current architecture

```mermaid
flowchart LR
  user[Browser or curl] -->|Host: app.localhost<br/>localhost:8080| traefik[Traefik proxy]
  user -->|Host: api.localhost<br/>localhost:8080| traefik

  subgraph public[public Docker network]
    traefik
    front[Static front-end<br/>nginx]
  end

  subgraph private[private Docker network]
    api[API<br/>Flask + Gunicorn]
    mysql[(MySQL)]
  end

  traefik --> front
  traefik --> api
  api --> mysql
```

## What this proves

- Public traffic enters only through Traefik.
- MySQL is reachable from the API network, not from the laptop.
- API and database containers are isolated from the public Docker network.

## Run

```bash
docker compose up -d --build --wait
```

## Prove it

Run the automated check:

```bash
./scripts/check.sh
```

Manual proof commands:

```bash
# Front-end through the proxy.
curl -H 'Host: app.localhost' http://localhost:8080/

# API through the proxy.
curl -H 'Host: api.localhost' http://localhost:8080/api/items

# Traefik dashboard API is available only on the local lab port.
curl http://localhost:8081/api/rawdata

# These should not contain HostPort entries.
docker inspect "$(docker compose ps -q api)" --format '{{json .NetworkSettings.Ports}}'
docker inspect "$(docker compose ps -q mysql)" --format '{{json .NetworkSettings.Ports}}'

# API and MySQL should only show the private network.
docker inspect "$(docker compose ps -q api)" --format '{{json .NetworkSettings.Networks}}'
docker inspect "$(docker compose ps -q mysql)" --format '{{json .NetworkSettings.Networks}}'
```

## Next stage preview

```mermaid
flowchart LR
  user[Client] --> proxy[Traefik]
  proxy --> api[API]
  api --> redis[(Redis cache)]
  api --> mysql[(MySQL)]
  redis -. "cache hit" .-> api
  mysql -. "cache miss" .-> api
```

Stage 02 keeps the network isolation and adds Redis on the private network so repeated API reads do not always hit MySQL.

## Stop

```bash
docker compose down -v
```

`-v` removes the teaching database volume so the next run starts clean.
