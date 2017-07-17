#!/bin/zsh

thisDir=$(cd $0:h && print $PWD)
source $thisDir:h/config.env

set -e

zparseopts -D -K n=o_dryrun

destDir=~/bin
[[ -d $destDir ]] || x mkdir -p $destDir
x cp -a $thisDir/myautostart.{zsh,d} $destDir

configDir=~/.config/autostart 
[[ -d $configDir ]] || x mkdir -p $configDir
x cp -a $thisDir/myautostart.desktop $configDir
