#!/bin/sh

dockerfile_before_context() {
    :
}

dockerfile_after_context() {
    :
}

multipass_authenticate() {
    local passphrase

    passphrase=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13)
    multipass set local.passphrase="$passphrase"

    for i in in 1 2 3 4 5
    do
        sleep 3
        docker exec -ti "$name" multipass authenticate "$passphrase" && return
    done
    die Cannot authenticate in multipass
}

docker_run() {
    docker run \
        -v /run/snapd.socket:/run/snapd.socket \
        -v /snap:/snap \
        -v /var/lib/snapd:/var/lib/snapd \
        -v /var/snap/multipass:/var/snap/multipass \
        --cap-add SYS_PTRACE --cap-add SYS_ADMIN --cap-add SYSLOG \
        --security-opt apparmor:unconfined --security-opt seccomp=unconfined \
        "$@"

    docker exec -ti --user root "$name" mount -t securityfs securityfs /sys/kernel/security
    multipass_authenticate
}

