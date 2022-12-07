#!/bin/sh

set -e
set -vx

CI_DOCKER="$1"
url="$2"
token="$3"

unregister_runner() {
    test -f token || return 0
    test -f .runner || return 0
}

register_runner() {
    echo $token >token
    docker exec -t $id sh -c "cd /build-runner && ./config.sh --labels docker --url $url --token $token --unattended && kill \$(cat pid) || true"
}

test -n "$token"
id=$(docker ps | awk "(\$2 == \"$CI_DOCKER\") { print \$1 }")

sh -$- unregister.sh "$id"
register_runner

