#!/bin/zsh

thisDir=$(cd $0:h && print $PWD)
source $thisDir/config.env

set -e

zparseopts -D -K n=o_dryrun

dev='Logitech Rechargeable Touchpad T650'
function devset {
    x xinput set-prop $dev "$@"
}

if xinput list-props $dev |grep libinput >& /dev/null;then

    devset 'libinput Tapping Enabled' 1
    devset 'libinput Click Method Enabled' 0 1; # for clickfinger
    devset 'libinput Tapping Button Mapping Enabled' 1 0; # for left-right-mid

else

    devset 'Synaptics Area' 0 4421 0 0
    devset Synaptics\ Soft\ Button\ Areas 4000 0 0 0 2000 3800 0 0

fi
