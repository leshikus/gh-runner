#!/bin/sh

set -e
set -vx

{
    id=$(docker ps | awk '($2 == "ci") { print $1 }')
    docker stop $id
    docker rmi --force ci
} || true
docker build -t ci .
docker run -t ci

