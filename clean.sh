#!/bin/sh

docker container prune -f --filter "until=48h"

none_images=$(docker images | awk '/^<none> +<none>/ { print $3}')
docker rmi -f $none_images

