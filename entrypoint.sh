#!/bin/sh

set -eu
set -vx

run_agent() {
    cd /build-runner
    while true
    do
        sleep 10
        test -f .runner || continue
        ./run.sh &
        echo $! >pid
        echo PID $(cat pid)
        ps --pid $(cat pid)
        wait $! || true
    done
}

run_agent

