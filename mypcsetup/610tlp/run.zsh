#!/bin/zsh

set -e

thisDir=$(cd $0:h && print $PWD)
source $thisDir:h/config.env


zparseopts -D -K n=o_dryrun

if ! rpm -q tlp >&/dev/null; then
    x dnf install tlp
fi

x sudo systemctl enable tlp

x sudo systemctl enable tlp-sleep

x sudo tlp start

