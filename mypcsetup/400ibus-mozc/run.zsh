#!/bin/zsh

thisDir=$(cd $0:h && print $PWD)
source $thisDir:h/config.env

set -e

zparseopts -D -K n=o_dryrun

ibus-setup &

echo Install these by hand";-)"
print -l $thisDir/*.txt
