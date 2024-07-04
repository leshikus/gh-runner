#!/bin/sh

dockerfile_before_context() {
    dockerfile_add_group libvirt
}

dockerfile_after_context() {
    :
}

docker_run() {
    mkdir -p "$agent_dir"/vagrant
    chmod 777 "$agent_dir"/vagrant
    docker_run_watcher \
        --env "http_proxy=$http_proxy" \
        --env "https_proxy=$https_proxy" \
        --env "no_proxy=$no_proxy" \
        -v "$agent_dir"/vagrant:/.vagrant.d -v /var/run/libvirt/:/var/run/libvirt/ \
        "$@"
}

