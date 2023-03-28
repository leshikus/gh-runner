#!/bin/sh

set -e
set -vx

test -n "$CI_DOCKER"
name=$(echo $CI_DOCKER | tr / .)

exec 1>"$name".log 2>&1

mkdir -p ~/.docker
touch ~/.docker/config.json
cp ~/.docker/config.json .

gid=$(stat -c "%g" /var/run/docker.sock)
gversion=$(curl --head -i https://github.com/actions/runner/releases/latest | awk '/^[lL]ocation: / { gsub(/.*v/, ""); gsub(/[^0-9]*$/, ""); print }')

cd $(dirname "$0")

{
    sh -$- unregister.sh $name
    docker rm -f $name
    echo $id stopped
    sh -$- clean.sh
} || true

sed -e "s/#DOCKER_GID#/$gid/g; s/#RUNNER_VERSION#/$gversion/g" Dockerfile.orig >Dockerfile

docker build -t $CI_DOCKER .

device=$(find /dev -type c \( -name 'nvidia*' -or -name renderD128 \) | awk '{ print " --device "$1":"$1 }')

docker run --hostname $(hostname) --restart unless-stopped -v /var/run/docker.sock:/var/run/docker.sock $device -t --name $name $CI_DOCKER &

