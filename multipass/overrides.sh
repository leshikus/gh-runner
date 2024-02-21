#!/bin/sh

dockerfile_before_context() {
    :
}

dockerfile_after_context() {
    :
}

docker_build() {
    rm -rf "$agent_dir"/home-snap
    cp -r "$HOME"/snap "$agent_dir"/home-snap
    docker build \
        --progress plain \
        "$@"
}

docker_run() {
    docker_run_watcher \
        -v /run/snapd.socket:/run/snapd.socket \
        -v /snap:/snap \
        -v /var/lib/snapd:/var/lib/snapd \
        -v /var/snap/multipass:/var/snap/multipass \
        -v /sys/kernel/security:/sys/kernel/security \
        --cap-add SYS_PTRACE --cap-add SYS_ADMIN --cap-add SYSLOG \
        --security-opt apparmor:unconfined --security-opt seccomp=unconfined \
        "$@"
}

