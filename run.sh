#!/bin/sh

die() {
    echo Error: $@
    exit 1
}

dockerfile_add_device_groups() {
    case " $docker_devices " in
       *\ /dev/dri\ *)
        dockerfile_add_group render
        ;;
       *\ /dev/kvm\ *)
        dockerfile_add_group kvm
        ;;
    esac
}

dockerfile_before_context() {
    dockerfile_add_group docker
}

dockerfile_after_context() {
    :
}

docker_build() {
    docker build \
        --build-arg "http_proxy=$http_proxy" \
        --build-arg "https_proxy=$https_proxy" \
        --build-arg "no_proxy=$no_proxy" \
        "$@"
}

docker_build_watcher() {
    cp watcher-entrypoint.sh "$watcher_dir"/entrypoint.sh
    {
        dockerfile_add_user
        dockerfile_add_group docker
        cat docker/Dockerfile.orig
        dockerfile_add_watcher_entrypoint
    } >"$watcher_dir"/Dockerfile

    docker_build -t watcher "$watcher_dir"
}

docker_run_watcher() {
    docker run \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --restart unless-stopped \
        -d --network none \
        -t --name $name.watcher watcher "$@"
}


docker_run() {
    docker_run_watcher \
        --env "http_proxy=$http_proxy" \
        --env "https_proxy=$https_proxy" \
        --env "no_proxy=$no_proxy" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        "$@"
}

parse_params() {
    test -n "$USER" || USER="$USERNAME"
    test -n "$USER" || USER="$LOGNAME"
    test -n "$USER"

    script_dir=$(dirname "$0")
    docker_context="$script_dir"/docker
    runner_label=
    docker_devices=
    skip_sanity_check=
    remove_runner=
    dont_rebuild_docker=
    become_root=
    token=${GITHUB_TOKEN:-}

    while test ! -z ${1+x}
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
   
    test -z ${iname+x} && die "missed a runner name"

    repo_path=$(echo "$iname" | sed -e 's#/[^/]*$##')
    name=$(echo "$iname" | tr / .)
    test -n "$skip_sanity_check" || \
        if ! git ls-remote "https://github.com/$repo_path" 1>/dev/null
        then
            die "invalid git repo path $repo_path from image $iname"
        fi
    context_label=$(basename "$docker_context")
    runner_label="$name,$context_label$runner_label"

    agent_dir="$HOME/.config/gh-runner/$name"
    watcher_dir="$HOME/.config/gh-runner/watcher"
    mkdir -p "$agent_dir" "$watcher_dir"

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

docker_clean() {
    docker container prune -f --filter "until=48h"
    none_images=$(docker images | awk '/^<none> +<none>/ { print $3 }')
    test -z "$none_images" || docker rmi -f $none_images
    docker rm -f "$name".watcher || true
    docker rm -f "$name" || true
}

dockerfile_add_user() {
    cat <<EOF
FROM ubuntu:$(lsb_release -rs)

RUN useradd -m --uid 1001 ghrunner
ENV DEBIAN_FRONTEND="noninteractive"
EOF
}

dockerfile_install_packages() {
    cat <<EOF
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    libicu-dev \
    ca-certificates \
    jq git \
    curl gpg
EOF
}

dockerfile_add_entrypoint() {
    cat <<EOF
USER ghrunner
WORKDIR /home/ghrunner
COPY --chown=ghrunner:ghrunner entrypoint.sh runner/ /home/ghrunner/

ENTRYPOINT ["/home/ghrunner/entrypoint.sh"]
CMD [""]
EOF
}

dockerfile_add_watcher_entrypoint() {
    cat <<EOF
USER ghrunner
COPY --chown=ghrunner:ghrunner entrypoint.sh /home/ghrunner/

ENTRYPOINT ["/home/ghrunner/entrypoint.sh"]
CMD [""]
EOF
}

dockerfile_add_group() {
    local gname
    local gid

    gname="$1"

    gid=$(getent group $gname | awk -F : '{ print $3 }')
    cat <<EOF
RUN groupadd -g $gid $1 && usermod -aG $gname ghrunner
EOF
}

generate_dockerfile() {
    {
        dockerfile_add_user
        dockerfile_add_device_groups
        dockerfile_install_packages
        dockerfile_before_context
        cat "$agent_dir"/Dockerfile.orig

        dockerfile_after_context
        dockerfile_add_entrypoint
        test -z "$become_root" || echo "USER root"
    } >"$agent_dir"/Dockerfile
}

docker_launch() {
    test -z "$dont_rebuild_docker" || return 0

    docker_clean
    generate_dockerfile
    docker_build_watcher

    cp entrypoint.sh "$agent_dir"

    docker_build \
        -t $iname "$agent_dir"

    docker_run --network host \
        --hostname $name \
        $docker_devices \
        $become_root \
        -t --name $name $iname
}

register_runner() {
    local gversion

    gversion=$(curl --head -i https://github.com/actions/runner/releases/latest | awk '/^[lL]ocation: / { gsub(/.*v/, ""); gsub(/[^0-9]*$/, ""); print }')

    test ! -f "$agent_dir"/runner-$gversion || return 0
    rm -rf "$agent_dir"/runner
    mkdir "$agent_dir"/runner
    (
        cd "$agent_dir"/runner
        curl -o actions-runner-linux-x64-$gversion.tar.gz -L https://github.com/actions/runner/releases/download/v$gversion/actions-runner-linux-x64-$gversion.tar.gz
        tar xzf actions-runner-linux-x64-$gversion.tar.gz
        rm actions-runner-linux-x64-$gversion.tar.gz
        ./config.sh --name $name --labels $runner_label --url https://github.com/$repo_path --token $token --unattended --replace
    )
    touch "$agent_dir"/runner-$gversion
}

remove_runner() {
    docker exec -u ghrunner -t $name ./config.sh remove --token $token || true
    docker_clean
    rm -f "$agent_dir"/token
    rm -rf "$agent_dir"/runner*
}

set -eu

parse_params "$@"

cd "$script_dir"

if test -n "$remove_runner"
then
    remove_runner
    exit 0
fi

register_runner
docker_launch

