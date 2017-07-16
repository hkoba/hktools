#!/bin/zsh

source $0:h:h/config.env
thisDir=$(cd $0:h && print $PWD)

set -e

zparseopts -D -K n=o_dryrun

scm=org.mate.Marco.global-keybindings

x gsettings set $scm switch-to-workspace-left  '<Primary><Alt>h'
x gsettings set $scm switch-to-workspace-down  '<Primary><Alt>j'
x gsettings set $scm switch-to-workspace-up    '<Primary><Alt>k'
x gsettings set $scm switch-to-workspace-right '<Primary><Alt>l'

x gsettings set org.mate.SettingsDaemon.plugins.media-keys screensaver '<Shift><Alt>l'
