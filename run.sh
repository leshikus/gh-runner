#!/bin/sh

die() {
    echo Error: $@
    exit 1
}

parse_params() {
    test -n "$USER" || USER="$USERNAME"
    test -n "$USER" || USER="$LOGNAME"
    test -n "$USER"

    script_dir=$(dirname "$0")
    docker_context="$script_dir"
    runner_label=

    while test -n "$1"
    do
        case "$1" in
            -t|--token)
                token="$2"
                shift 2
                ;;
            -nr|--no-rebuild)
                dont_rebuild_docker=true
                shift
                ;;
            -r|--remove)
                remove_runner=true
                shift
                ;;
            -s|--skip-check)
                skip_sanity_check=true
                shift
                ;;
            -l|--labels)
                runner_label="$runner_label,$2"
                shift 2
                ;;
            -c|--context)
                docker_context="$2"
                shift 2
                ;;
            -b|--become)
                become_root="--env RUNNER_ALLOW_RUNASROOT=1"
                shift
                ;;
            -v|--verbose)
                set -vx
                shift
                ;;
            -h|--help)
                cat "$script_dir"/README.md
                exit 0
                ;;
            -*)
                die "unknown option $1"
                ;;
            *)
                iname="$1"
                shift
                ;;
        esac
    done
   
    test -n "$iname" || die "missed a runner name"     

    url=https://github.com/$(echo "$iname" | sed -e 's#/[^/]*$##')
    name=$(echo "$iname" | tr / .)
    test -n "$skip_sanity_check" || \
        if ! git ls-remote "$url" 1>/dev/null
        then
            die "invalid git repo $url from image $iname"
        fi
    runner_label="$name$runner_label"

    agent_dir="$HOME/.config/gh-runner/$name"
    mkdir -p "$agent_dir"/creds

    date >"$agent_dir"/log  
    tail -f "$agent_dir"/log &
    exec 2>&1 1>"$agent_dir".log

    if test -f "$agent_dir"/token
    then
        if test -z "$token"
        then
            token=$(cat "$agent_dir"/token)
        else
            echo "$token" >"$agent_dir"/token
        fi
    else
        if test -z "$token"
        then
            echo "Missed a github registration token"
            exit 1
        fi
        echo "$token" >"$agent_dir"/token
    fi

    if test -f "$docker_context"
    then
        docker_context_dockerfile="$docker_context"
    else
        docker_context_dockerfile="$docker_context"/Dockerfile.orig
    fi
    cp "$docker_context_dockerfile" "$agent_dir"/Dockerfile.orig
}

create_docker_proxy() {
    HTTP_PROXY=${HTTP_PROXY:-$http_proxy}
    HTTPS_PROXY=${HTTPS_PROXY:-$https_proxy}

    mkdir -p ~/.docker
    test -z "$HTTPS_PROXY" || cat <<EOF >~/.docker/config.json
{
 "proxies":
 {
   "default":
   {
     "httpProxy": "$HTTP_PROXY",
     "httpsProxy": "$HTTPS_PROXY",
     "noProxy": "$no_proxy"
   }
 }
}
EOF

    touch ~/.docker/config.json
    cp ~/.docker/config.json "$agent_dir"/
}

clean_docker() {
    docker container prune -f --filter "until=48h"
    none_images=$(docker images | awk '/^<none> +<none>/ { print $3 }')
    test -z "$none_images" || docker rmi -f $none_images
    docker rm -f "$name" || true
}

dockerfile_add_user() {
    cat <<EOF >>"$agent_dir"/Dockerfile
RUN mkdir -p /runner && \
    useradd -d /runner --uid 1001 ghrunner && \
    chown ghrunner:ghrunner /runner
EOF
}

dockerfile_add_docker() {
    local gid

    gid=$(stat -c "%g" /var/run/docker.sock)

    create_docker_proxy
    cat <<EOF >>"$agent_dir"/Dockerfile
RUN groupadd -g $gid docker && \
    usermod -aG docker ghrunner


USER ghrunner
RUN mkdir -p /runner/.docker

COPY config.json /runner/.docker/

USER root
EOF
}

dockerfile_add_agent() {
    local gversion

    gversion=$(curl --head -i https://github.com/actions/runner/releases/latest | awk '/^[lL]ocation: / { gsub(/.*v/, ""); gsub(/[^0-9]*$/, ""); print }')

    cat <<EOF >>"$agent_dir"/Dockerfile
USER ghrunner
WORKDIR /runner

RUN curl -o actions-runner-linux-x64-$gversion.tar.gz -L https://github.com/actions/runner/releases/download/v$gversion/actions-runner-linux-x64-$gversion.tar.gz && \
    tar xzf actions-runner-linux-x64-$gversion.tar.gz
EOF
}

dockerfile_add_entrypoint() {
    cat <<EOF >>"$agent_dir"/Dockerfile
USER ghrunner
COPY entrypoint.sh /runner

ENTRYPOINT ["/runner/entrypoint.sh"]
EOF
}

generate_dockerfile() {
    grep '^FROM ' "$agent_dir"/Dockerfile.orig >"$agent_dir"/Dockerfile
    dockerfile_add_user

    mount_docker_sock=
    if fgrep -q docker.io "$agent_dir"/Dockerfile.orig
    then
        mount_docker_sock="-v /var/run/docker.sock:/var/run/docker.sock"
        dockerfile_add_docker
    fi
    grep -v '^FROM ' "$agent_dir"/Dockerfile.orig >>"$agent_dir"/Dockerfile

    mount_vagrant=
    if fgrep -q vagrant "$agent_dir"/Dockerfile.orig
    then
        mkdir -p $agent_dir/vagrant
        mount_vagrant="-v $agent_dir/vagrant:/runner/.vagrant.d -v /var/run/libvirt/:/var/run/libvirt/"
    fi

    dockerfile_add_agent
    dockerfile_add_entrypoint
    test -z "$become_root" || echo "USER root" >>"$agent_dir"/Dockerfile
}

build_docker() {
    test -z "$dont_rebuild_docker" || return 0

    clean_docker
    generate_dockerfile

    cp entrypoint.sh "$agent_dir"

    docker build -t "$iname" "$agent_dir"

    mount_devices=$(find /dev -type c -name 'nvidia*' | awk '{ print " --device "$1":"$1 }')
    test ! -d /dev/dri || mount_device="$mount_devices --device /dev/dri:/dev/dri"
    
    docker run -d --network host \
        --restart unless-stopped \
        --hostname $name \
        $mount_vagrant \
        $mount_docker_sock \
        $mount_devices \
        $become_root \
        -t --name $name $iname
}

register_runner() {
    test ! -f "$agent_dir"/creds/.runner || return 0
    docker exec -u ghrunner -t "$name" ./config.sh --name $name --labels $runner_label --url $url --token $token --unattended --replace
    for f in .runner .credentials .credentials_rsaparams
    do
        docker cp "$name":/runner/"$f" "$agent_dir"/creds
    done
}

remove_runner() {
    docker exec -u ghrunner -t "$name" ./config.sh remove --token $token || true
    clean_docker
    rm -f "$agent_dir"/token "$agent_dir"/creds/.runner
}

set -e

parse_params "$@"

cd "$script_dir"

if test -n "$remove_runner"
then
    remove_runner
    exit 0
fi

build_docker
register_runner

