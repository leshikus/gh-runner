#!/bin/sh

set -e
set -vx

mkdir -p ~/.docker/ ~/volume
touch ~/.docker/config.json
cp ~/.docker/config.json .

gid=$(stat -c "%g" /var/run/docker.sock)
gversion=$(curl -X HEAD -i https://github.com/actions/runner/releases/latest | awk '/^location: / { gsub(/.*v/, ""); gsub(/[^0-9]*$/, ""); print }')


{
    id=$(docker ps | awk '($2 == "ci") { print $1 }')
    docker stop $id
    docker container prune -a -f
} || true

sed -e "s/#DOCKER_GID#/$gid/g; s/#RUNNER_VERSION#/$gversion/g" Dockerfile.orig >Dockerfile

docker build -t ci .

docker run -v /var/run/docker.sock:/var/run/docker.sock -v ~/build-runner:/build-runner/_work -t ci

