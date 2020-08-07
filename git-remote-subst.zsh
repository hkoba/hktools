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

for remote in $(git remote); do

    remoteUrl=$(git config remote.$remote.url)

    [[ $remoteUrl == $from* ]] || continue

    new_remote=${remoteUrl/$~from/$to}

    x git remote set-url $remote $new_remote

done

