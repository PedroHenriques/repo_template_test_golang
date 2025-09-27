#!/bin/sh
set -e;

docker compose -f setup/local/docker-compose.yml -p myapp down;
docker compose -f setup/local/docker-compose.elk.yml -p myapp_elk down;
docker system prune -f --volumes;