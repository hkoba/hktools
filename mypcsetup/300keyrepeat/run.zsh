#!/bin/zsh

source $0:h:h/config.env
thisDir=$(cd $0:h && print $PWD)

set -e

zparseopts -D -K n=o_dryrun

scm=org.mate.peripherals-keyboard

x gsettings set $scm delay 330
x gsettings set $scm rate 50

