#!/bin/zsh

thisDir=$(cd $0:h && print $PWD)
source $thisDir/config.env

set -e

zparseopts -D -K n=o_dryrun

fn=~/.Xmodmap
if [[ -r $fn ]]; then
    x xmodmap $fn
fi

