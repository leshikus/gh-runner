#!/bin/sh

set -eu
set -vx

run_agent() {
    cd /build-runner
    while true
    do
        sleep 10
        test -f .credentials || continue
        ./run.sh &
        echo $! >pid
        wait $!
    done
}

run_agent

