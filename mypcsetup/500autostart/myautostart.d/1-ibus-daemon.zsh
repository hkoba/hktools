#!/bin/zsh

thisDir=$(cd $0:h && print $PWD)
source $thisDir/config.env

set -e

zparseopts -D -K n=o_dryrun

if ! fuser -v =ibus-daemon >& /dev/null; then
    x ibus-daemon -vd --xim
fi

