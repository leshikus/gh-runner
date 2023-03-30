#!/bin/sh

parse_params() {
    test -n "$USER" || USER="$USERNAME"
    test -n "$USER" || USER="$LOGNAME"
    test -n "$USER"

    while test -n "$1"
    do
        case "$1" in
            -t|--token)
                token="$2"
                shift 2
                ;;
            -nr|--no-rebuild)
                norebuild_docker=true
                shift
                ;;
            -r|--remove)
                remove_runner=true
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
                iname="$1"
                url=https://github.com/$(echo "$iname" | sed -e 's#/[^/]*$##')
                name=$(echo "$iname" | tr / .)
                if ! git ls-remote "$url" 1>/dev/null
                then
                    echo "Invalid git repo $url from image $iname"
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

    tmp_dir="/tmp/$USER/gh-runner/$name"
    mkdir -p "$tmp_dir"

    date >"$tmp_dir"/log  
    tail -f "$tmp_dir"/log &
    exec 2>&1 1>"$tmp_dir".log

    if test -f "$tmp_dir"/token
    then
        if test -z "$token"
        then
            token=$(cat "$tmp_dir"/token)
        else
            echo "$token" >"$tmp_dir"/token
        fi
    else
        if test -z "$token"
        then
            echo "Missed a github registration token"
            exit 1
        fi
        echo "$token" >"$tmp_dir"/token
    fi
}

create_docker_proxy() {
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
    cp ~/.docker/config.json "$tmp_dir"/
}

clean_docker() {
    docker container prune -f --filter "until=48h"
    none_images=$(docker images | awk '/^<none> +<none>/ { print $3}')
    test -z "$none_images" || docker rmi -f $none_images
    docker rm -f "$name" || true
}

build_docker() {
    test -z "$norebuild_docker" || return 0

    clean_docker
    create_docker_proxy
    
    gid=$(stat -c "%g" /var/run/docker.sock)
    gversion=$(curl --head -i https://github.com/actions/runner/releases/latest | awk '/^[lL]ocation: / { gsub(/.*v/, ""); gsub(/[^0-9]*$/, ""); print }')
    
    sed -e "s/#DOCKER_GID#/$gid/g; s/#RUNNER_VERSION#/$gversion/g" Dockerfile.orig >"$tmp_dir"/Dockerfile
    cp entrypoint.sh "$tmp_dir"
    docker build -t "$iname" "$tmp_dir"

    device=$(find /dev -type c -name 'nvidia*' | awk '{ print " --device "$1":"$1 }')
    test ! -d /dev/dri || device="$device --device /dev/dri:/dev/dri"
    
    docker run -d --hostname $(hostname) --restart unless-stopped -v /var/run/docker.sock:/var/run/docker.sock $device -t --name $name $iname
}

register_runner() {
    if test -f "$tmp_dir"/.runner
    then
        for f in .runner .credentials .credentials_rsaparams
        do
            docker cp "$tmp_dir"/"$f" "$name":/build-runner/
        done
    else
        docker exec -u ghrunner -t "$name" sh -c "cd /build-runner && ./config.sh --name $name --labels $name --url $url --token $token --unattended"
        for f in .runner .credentials .credentials_rsaparams
        do
            docker cp "$name":/build-runner/"$f" "$tmp_dir"/
        done
    fi
}

remove_runner() {
    docker exec -u ghrunner -t "$name" sh -c "cd /build-runner; ./config.sh remove --token $token" || true
    clean_docker
    rm "$tmp_dir"/token "$tmp_dir"/.runner
}

set -e
cd $(dirname "$0")

parse_params "$@"

if test -n "$remove_runner"
then
    remove_runner
    exit 0
fi

build_docker
register_runner

