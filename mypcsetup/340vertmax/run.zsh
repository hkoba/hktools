#!/bin/zsh

source $0:h:h/config.env
thisDir=$(cd $0:h && print $PWD)

set -e

zparseopts -D -K n=o_dryrun

x gsettings set org.mate.Marco.general action-double-click-titlebar 'toggle_maximize_vertically'
