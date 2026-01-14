#!/bin/bash
# Run the container using docker-compose
DOCKER_COMMAND=$(which docker-compose)
if [[ "$OSTYPE" == "darwin"* ]]; then
    docker compose run --rm asm
else
    docker-compose run --rm asm
fi

# docker-compose -f ./docker-compose.yml -p x up -d