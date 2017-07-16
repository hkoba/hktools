#!/bin/zsh

source $0:h:h/config.env
thisDir=$(cd $0:h && print $PWD)

set -e

zparseopts -D -K n=o_dryrun

x sudo dnf install $(trim_comment $thisDir/pkg-*.lst)



