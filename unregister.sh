#!/bin/sh

set -e
set -vx

name="$1"
test -n "$name"

test -f "$name".token || exit 0
docker exec -t $name sh -c "cd /build-runner; ./config.sh remove --token "$(cat "$name".token) || true

