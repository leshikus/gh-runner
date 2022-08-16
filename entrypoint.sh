#!/usr/bin/env bash
set -eu
set -vx

restart_agent() {
    test -f url || return
    test -f pid && kill $(cat pid)
    test -f token.running && ./config.sh remove --token $(cat token.running)
    mv token token.running

    name=$(cat name) || name=$(hostname)
    ./config.sh --url $(cat url) --token $(cat token.running) --name $name --unattended

    while true
    do
        sleep 11
        ./run.sh
    done &
    echo $! >pid
}

run_watchdog() {
    cd /build-runner
    while true
    do
        sleep 10
        test -f token || continue
        restart_agent || true
    done
}

run_watchdog



