#!/bin/sh

set -e
set -vx

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
    docker container prune -f
} || true

sed -e "s/#DOCKER_GID#/$gid/g; s/#RUNNER_VERSION#/$gversion/g" Dockerfile.orig >Dockerfile

docker build -t ci .

umount /tmp/build-runner-work || true
mkdir -p /tmp/build-runner-work
sudo chown 1001:1001 /tmp/build-runner-work
sudo mount -t tmpfs -o size=4G tmpfs /tmp/build-runner-work

device=$(find /dev -name 'nvidia*' -type c | awk '{ print " --device "$1":"$1 }')

docker run -v /var/run/docker.sock:/var/run/docker.sock -v /tmp/build-runner-work:/build-runner/_work $device -t ci

umount /tmp/build-runner-work || true
