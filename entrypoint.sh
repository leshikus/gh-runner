#!/usr/bin/env bash
set -eu

cd /build-runner

test -f registered || {
    ./config.sh --url https://github.com/intel-ai/omniscidb --token $TOKEN
    touch registered
}

while true
do
    ./run.sh
    sleep 10
done

