#!/bin/sh

parse_params() {
    test -n "$USER" || USER="$USERNAME"
    test -n "$USER" || USER="$LOGNAME"
    mkdir -p /tmp/"$USER"/runner

    while test -n "$1"
    do
        case "$1" in
            -t|--token)
                token="$2"
                shift 2
                ;;
            -r|--rebuild)
                rebuild_docker=true
                shift
                ;;
            -h|--help)
                cat README.md
                exit 0
                ;;
            -*)
                echo "Unknown option $1"
                exit 1
                ;;
            *)
                name="$1"
                url=https://github.com/$(echo "$name" | sed -e 's#/[^/]*$##')
                if ! git ls-remote "$url" 1>/dev/null
                then
                    echo "Invalid git repo $url"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    if test -z "$name"
    then
        echo "Missed a runner name"     
        exit 1
    fi

    if test -f /tmp/"$USER"/runner/"$name".token
    then
        if test -n "$token"
        then
        else
            token=$(cat /tmp/"$USER"/runner/"$name".token)
            echo "Missed a github registration token"
            exit 1
        fi
    else
        rebuild_docker=true
        if test -z "$token"
        then
            echo "Missed a github registration token"
            exit 1
        fi
    fi

    if test -z "$token"
    then
        if test -f /tmp/"$USER"/runner/"$name".token
        then
            token=$(cat /tmp/"$USER"/runner/"$name".token)
        else
        fi
    else
        echo "$token" >/tmp/"$USER"/runner/"$name".token
    fi
}

build() {
    test -n "$CI_DOCKER"
    name=$(echo $CI_DOCKER | tr / .)
    
    exec 1>"$name".log 2>&1
    
    mkdir -p ~/.docker
    touch ~/.docker/config.json
    cp ~/.docker/config.json .
    
    gid=$(stat -c "%g" /var/run/docker.sock)
    gversion=$(curl --head -i https://github.com/actions/runner/releases/latest | awk '/^[lL]ocation: / { gsub(/.*v/, ""); gsub(/[^0-9]*$/, ""); print }')
    
    cd $(dirname "$0")
    
    {
            sh -$- unregister.sh $name
            docker rm -f $name
            echo $id stopped
            sh -$- clean.sh
    } || true
    
    sed -e "s/#DOCKER_GID#/$gid/g; s/#RUNNER_VERSION#/$gversion/g" Dockerfile.orig >Dockerfile
    
    docker build -t $CI_DOCKER .
    
    device=$(find /dev -type c \( -name 'nvidia*' -or -name renderD128 \) | awk '{ print " --device "$1":"$1 }')
    
    docker run --hostname $(hostname) --restart unless-stopped -v /var/run/docker.sock:/var/run/docker.sock $device -t --name $name $CI_DOCKER &
}


set -e
set -vx
cd $(dirname "$0")

parse_params "$@"

#if test -z "$rebuild_docker" || sh -$- rebuild.sh
#g


