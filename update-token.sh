#!/bin/sh

set -e
set -vx

test -n "$CI_DOCKER"
name=$(echo $CI_DOCKER | tr / .)
test -f "$name".token

url=https://github.com/$(echo "$CI_DOCKER" | sed -e 's#/[^/]*$##')

register_runner() {
    token=$(cat "$name".token)
    internal_pid=$(docker exec -t $name cat pid || true)
    docker exec -t $name sh -c "cd /build-runner && ./config.sh --name $name --labels $name --url $url --token $token --unattended || true"
    test ! -z "$internal_pid" && docker exec -t $name kill $internal_pid
}

sh -$- unregister.sh "$name"
register_runner

