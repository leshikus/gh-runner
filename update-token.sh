#!/bin/sh

set -e
set -vx

url="$1"
token="$2"

unregister_runner() {
    test -f token || return 0
    test -f .runner || return 0

}

register_runner() {
    echo $token >token
    docker exec -t $id sh -c "cd /build-runner && ./config.sh --url $url --token $token --unattended && kill \$(cat pid) || true"
}

test -n "$token"
id=$(docker ps | awk '($2 == "ci") { print $1 }')

sh -$- unregister.sh "$id"
register_runner

