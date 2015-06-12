#!/bin/zsh

set -u
setopt err_return

progname=$0:t

function usage {
  cat <<EOF
Usage: $progname FROM TO
EOF
  exit
}

function x {
  (($#o_quiet))  || print -- "#" "$@"
  (($#o_dryrun)) && return
  "$@"
}

o_dryrun=() o_quiet=()
zparseopts -D -K n=o_dryrun q=o_quiet

((ARGC == 2)) || usage

from=$1
to=$2
remote=$(git config remote.origin.url)

new_remote=${remote/$~from/$to}

x git remote set-url origin $new_remote
