#!/bin/zsh

source $0:h:h/config.env
thisDir=$(cd $0:h && print $PWD)

set -e

zparseopts -D -K n=o_dryrun

x gsettings set org.mate.terminal.keybindings prev-tab '<Primary>F3'

x gsettings set org.mate.terminal.keybindings next-tab '<Primary>F4'
