#!/usr/bin/env bash
set -eu

restart_agent() {
    test -f url || return
    test -f pid && kill $(cat pid)
    test -f token.running && ./config.sh remove --token $(cat token.running)
    mv token token.running
    ./config.sh --url $(cat url) --token $(cat token.running)

    (
        while true
        do
            sleep 10
            ./run.sh
        done
    ) &
    echo $! >pid
}

run_watchdog() {
    cd /build-runner
    while true
    do
        sleep 1
        test -f token || continue
        restart_agent
    done
}

run_watchdog



