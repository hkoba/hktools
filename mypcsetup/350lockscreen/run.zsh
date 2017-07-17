#!/bin/zsh

source $0:h:h/config.env
thisDir=$(cd $0:h && print $PWD)

set -e

zparseopts -D -K n=o_dryrun R=o_reset

gset org.mate.session idle-delay 5
gset org.mate.screensaver lock-enabled true
gset org.mate.screensaver idle-activation-enabled true
