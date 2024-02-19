#!/bin/sh

set -eu
#set -vx

while true
do
    docker run --rm "$@"
    sleep 5
done

