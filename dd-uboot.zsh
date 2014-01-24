#!/bin/zsh

set -e
function die { echo 1>&2 $*; exit 1}

progfile=$0
function usage {
    ((! ARGC)) || echo 1>&2 $*;
    cat 1>&2 <<EOF; exit 1
Usage: ${progfile:t} [-r | -w] DEV [IMAGE]
EOF
}

function x {
    print -- "$@"
    if (($#o_dryrun)); then
	return
    fi
    "$@"
}

#----------------------------------------

dd_seek=2
dd_cf=(
    bs=512 count=592
)

function cmd--r {
    local dev=$1; shift
    local opt; ((ARGC)) && opt+=(of=$1)
    x dd if=$dev $opt $dd_cf skip=$dd_seek
}

function cmd--w {
    local dev=$1; shift
    local opt; ((ARGC)) && opt+=(if=$1)
    x dd of=$dev $opt $dd_cf seek=$dd_seek
}

#----------------------------------------

zparseopts -D -K n=o_dryrun

((ARGC)) && [[ $1 == -* ]] || usage

cmd=cmd-$1; shift

zparseopts -D -K n=o_dryrun

(($+functions[$cmd])) || usage "Unknown command: $cmd"

$cmd "$@"
