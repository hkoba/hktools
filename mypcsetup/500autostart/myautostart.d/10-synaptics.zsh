#!/bin/zsh

thisDir=$(cd $0:h && print $PWD)
source $thisDir/config.env

set -e

zparseopts -D -K n=o_dryrun

x xinput set-prop 'SynPS/2 Synaptics TouchPad' 'Synaptics Area' 0 4421 0 0
x xinput set-prop 'SynPS/2 Synaptics TouchPad' Synaptics\ Soft\ Button\ Areas 4000 0 0 0 2000 3800 0 0
