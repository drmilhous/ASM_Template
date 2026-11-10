#!/bin/bash
# docker build -f DockerFile -t asm-template .
#check if mac
if [[ "$OSTYPE" == "darwin"* ]]; then
    docker compose build
else
    docker-compose build
fi
# docker run -it --rm asm-template