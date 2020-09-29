#!/bin/zsh

set -u
setopt err_return

progname=$0:t

function usage {
  cat 1>&2 <<EOF
Usage: $progname [-n] [-q] [-C DIR] FROM TO
EOF
  exit 1
}

function x {
  (($#o_quiet))  || print -- "#" "$@"
  (($#o_dryrun)) && return
  "$@" || return $?
}

o_dryrun=() o_quiet=() o_chdir=()
zparseopts -D -K n=o_dryrun q=o_quiet C:=o_chdir

((ARGC == 2)) || usage

# -C ディレクトリ名
# で、↑このディレクトリに cd してから動作
if (($#o_chdir)); then
    cd $o_chdir
fi

if ((! $#o_quiet)); then
    print PWD=$PWD
fi

from=$1
to=$2

for remote in $(git remote); do

    remoteUrl=$(git config remote.$remote.url)

    [[ $remoteUrl == $from* ]] || continue

    new_remote=${remoteUrl/$~from/$to}

    x git remote set-url $remote $new_remote || break

done

git submodule foreach --recursive $0 $o_dryrun $o_quiet $from $to
