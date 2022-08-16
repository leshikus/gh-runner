#!/bin/sh

set -e
set -vx

mkdir -p ~/.docker/
touch ~/.docker/config.json
cp ~/.docker/config.json .

{
    id=$(docker ps | awk '($2 == "ci") { print $1 }')
    docker stop $id
    docker rmi --force ci
} || true
docker build -t ci .
docker run -v /var/run/docker.sock:/var/run/docker.sock -t ci

