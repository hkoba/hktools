#!/bin/zsh

thisDir=$(cd $0:h && print $PWD)
source $thisDir:h/config.env

set -e

zparseopts -D -K n=o_dryrun

destDir=~/bin
[[ -d $destDir ]] || x mkdir -p $destDir
x ln -vnsfr $thisDir/myautostart.{zsh,d} $destDir

configDir=~/.config/autostart 
[[ -d $configDir ]] || x mkdir -p $configDir
x cp -a $thisDir/myautostart.desktop $configDir
