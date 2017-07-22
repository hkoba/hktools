#!/bin/zsh

source $0:h:h/config.env
thisDir=$(cd $0:h && print $PWD)

zparseopts -D -K n=o_dryrun

((ARGC)) || die "Usage: $0 [-n] HOST"

destHost=$1; shift

echo "#" Setting up mindots
x ssh -t $destHost mindots/setup.zsh

echo "#" Run chsh
x ssh -t $destHost chsh
