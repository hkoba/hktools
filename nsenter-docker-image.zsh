#!/bin/zsh

emulate -L zsh

scriptFn=$0

function usage {
    cat 1>&2 <<EOF
Usage: ${scriptFn:t} IMAGE_NAME
EOF
    exit 1
}

#----------------------------------------

((ARGC)) || usage

imageName=$1

cid=$(docker container ls -q --filter ancestor=$imageName) || return 1

pid=$(docker inspect --format '{{.State.Pid}}' $cid) || return 1

sudo=()
[[ -r /proc/$pid/ns ]] || sudo=(sudo)

$sudo nsenter --target $pid --mount --uts --ipc --net --pid /bin/bash || return 1
