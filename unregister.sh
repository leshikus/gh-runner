#!/bin/sh

set -e
set -vx

id="$1"
test -n "$id"

test -f token || exit 0
docker exec -t $id sh -c "cd /build-runner; ./config.sh remove --token "$(cat token) || true
rm token

