#!/bin/sh

set -e
#set -vx

mkdir -p ~/.docker/ ~/volume
touch ~/.docker/config.json
cp ~/.docker/config.json .

gid=$(stat -c "%g" /var/run/docker.sock)
gversion=$(curl -X HEAD -i https://github.com/actions/runner/releases/latest | awk '/^location: / { gsub(/.*v/, ""); gsub(/[^0-9]*$/, ""); print }')

cd $(dirname "$0")

{
    id=$(docker ps | awk '($2 == "ci") { print $1 }')
    sh -$- unregister.sh $id
    docker stop $id
    sh -$- clean.sh
} || true

sed -e "s/#DOCKER_GID#/$gid/g; s/#RUNNER_VERSION#/$gversion/g" Dockerfile.orig >Dockerfile

docker build -t ci .

device=$(find /dev -name 'nvidia*' -type c | awk '{ print " --device "$1":"$1 }')

docker run -v /var/run/docker.sock:/var/run/docker.sock $device -t ci &
disown

