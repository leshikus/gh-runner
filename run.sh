#!/bin/sh

die() {
    echo Error: $@
    exit 1
}


dockerfile_before_context() {
    local gid

    gid=$(stat -c "%g" /var/run/docker.sock)

    dockerfile_add_group docker

    cat <<EOF >>"$agent_dir"/Dockerfile
RUN mkdir -p /home/ghrunner/.docker

COPY config.json /home/ghrunner/.docker/

USER root
EOF
}

dockerfile_after_context() {
    case " $docker_devices " in
       *\ /dev/dri\ *)
        dockerfile_add_group render
        ;;
       *\ /dev/kvm\ *)
        dockerfile_add_group kvm
        ;;
    esac
}

docker_build() {
    docker build \
        --progress plain \
        "$@"
}

docker_run() {
    # nvidia: /dev/nvidia0 /dev/nvidia-caps /dev/nvidiactl /dev/nvidia-modeset /dev/nvidia-uvm /dev/nvidia-uvm-tools

    docker run \
        -v /var/run/docker.sock:/var/run/docker.sock \
        $docker_devices \
        "$@"
}


parse_params() {
    test -n "$USER" || USER="$USERNAME"
    test -n "$USER" || USER="$LOGNAME"
    test -n "$USER"

    script_dir=$(dirname "$0")
    docker_context="$script_dir"
    runner_label=
    docker_devices=

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
                label=$(basename "$docker_context")
                runner_label="$runner_label,$label"
                shift 2
                ;;
            -b|--become)
                become_root="--env RUNNER_ALLOW_RUNASROOT=1"
                shift
                ;;
            -d|--device)
                echo Mounting $(ls "$2") || die "$2 not found"
                docker_devices="$docker_devices --device $2"
                shift 2
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
    touch "$agent_dir"/creds/.placeholder

    date >"$agent_dir"/log  
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

    if test -n "$docker_devices"
    then
        echo "$docker_devices" >"$agent_dir"/device
    else
        docker_devices=$(cat "$agent_dir"/device) || true
    fi

    cp "$docker_context"/Dockerfile.orig "$agent_dir"/
    test ! -f "$docker_context"/overrides.sh || . "$docker_context"/overrides.sh
}

create_docker_proxy() {
    HTTP_PROXY=${HTTP_PROXY:-$http_proxy}
    HTTPS_PROXY=${HTTPS_PROXY:-$https_proxy}

    mkdir -p ~/.docker
    test -z "$HTTPS_PROXY" || cat <<EOF >"$agent_dir"/config.json
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
}

clean_docker() {
    docker container prune -f --filter "until=48h"
    none_images=$(docker images | awk '/^<none> +<none>/ { print $3 }')
    test -z "$none_images" || docker rmi -f $none_images
    docker rm -f "$name" || true
}

dockerfile_add_user() {
    cat <<EOF >>"$agent_dir"/Dockerfile
RUN useradd -m --uid 1001 ghrunner
EOF
}

dockerfile_add_agent() {
    local gversion

    gversion=$(curl --head -i https://github.com/actions/runner/releases/latest | awk '/^[lL]ocation: / { gsub(/.*v/, ""); gsub(/[^0-9]*$/, ""); print }')

    cat <<EOF >>"$agent_dir"/Dockerfile
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    curl \
    tar \
    libicu-dev \
    ca-certificates

USER ghrunner
WORKDIR /home/ghrunner

RUN curl -o actions-runner-linux-x64-$gversion.tar.gz -L https://github.com/actions/runner/releases/download/v$gversion/actions-runner-linux-x64-$gversion.tar.gz && \
    tar xzf actions-runner-linux-x64-$gversion.tar.gz
EOF
}

dockerfile_add_entrypoint() {
    cat <<EOF >>"$agent_dir"/Dockerfile
USER ghrunner
COPY --chown=ghrunner:ghrunner entrypoint.sh creds/.* /home/ghrunner/

ENTRYPOINT ["/home/ghrunner/entrypoint.sh"]
CMD [""] FIXME
EOF
}

dockerfile_add_group() {
    local gname
    local gid

    gname="$1"

    gid=$(getent group $gname | awk -F : '{ print $3 }')
    cat <<EOF >>"$agent_dir"/Dockerfile
USER root
RUN groupadd -g $gid $1 && usermod -aG $gname ghrunner
USER ghrunner
EOF
}

generate_dockerfile() {
    grep '^FROM ' "$agent_dir"/Dockerfile.orig >"$agent_dir"/Dockerfile
    dockerfile_add_user
    dockerfile_before_context
    grep -v '^FROM ' "$agent_dir"/Dockerfile.orig >>"$agent_dir"/Dockerfile

    dockerfile_add_agent
    dockerfile_add_entrypoint
    dockerfile_after_context

    test -z "$become_root" || echo "USER root" >>"$agent_dir"/Dockerfile
}

docker_launch() {
    test -z "$dont_rebuild_docker" || return 0

    clean_docker
    generate_dockerfile

    cp entrypoint.sh "$agent_dir"

    create_docker_proxy
    docker_build \
        --build-arg http_proxy \
        --build-arg https_proxy \
        --build-arg no_proxy \
        -t "$iname" "$agent_dir"

    docker_run -d --network host \
        --env http_proxy \
        --env https_proxy \
        --env no_proxy \
        --restart unless-stopped \
        --hostname $name \
        $become_root \
        -t --name $name $iname
}

register_runner() {
    test ! -f "$agent_dir"/creds/.runner || return 0
    for f in .runner .credentials .credentials_rsaparams
    do
        docker cp "$name":/home/ghrunner/"$f" "$agent_dir"/creds
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

docker_launch

