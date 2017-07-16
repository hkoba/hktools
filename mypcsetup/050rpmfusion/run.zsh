#!/bin/zsh

source $0:h:h/config.env
thisDir=$(cd $0:h && print $PWD)

set -e

zparseopts -D -K n=o_dryrun

relver=$(fedora-release)
free=https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$relver.noarch.rpm
nonfree=https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$relver.noarch.rpm


x sudo dnf install $free
x sudo dnf install $nonfree

