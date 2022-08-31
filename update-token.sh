#!/bin/sh

set -e
set -vx

url="$1"
token="$2"

test -n "$token"
id=$(docker ps | awk '($2 == "ci") { print $1 }')

test ! -f token || docker exec -t $id sh -c "cd /build-runner; ./config.sh remove --token "$(cat token)
echo $token >token

docker exec -t $id sh -c "cd /build-runner; ./config.sh --url $url --token $token --unattended; kill \$(cat pid)"


