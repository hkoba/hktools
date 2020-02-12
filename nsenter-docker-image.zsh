#!/bin/zsh

emulate -L zsh

scriptFn=$0

function usage {
    cat 1>&2 <<EOF
Usage: ${scriptFn:t} IMAGE_NAME [COMMAND...]
EOF
    exit 1
}

function die { echo 1>&2 $*; exit 1 }

#----------------------------------------

((ARGC)) || usage

imageName=$1; shift
((ARGC)) || argv=(/bin/bash)

cid=$(docker container ls -q --filter ancestor=$imageName) || return 1

[[ -n $cid ]] || die "Can't find container for image $imageName"

pid=$(docker inspect --format '{{.State.Pid}}' $cid) || return 1

[[ -n $pid ]] || die "Can't find pid for container $cid"

sudo=()
[[ -r /proc/$pid/ns ]] || sudo=(sudo)

$sudo nsenter --target $pid --mount --uts --ipc --net --pid "$argv[@]" || return 1
