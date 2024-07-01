#!/bin/zsh

emulate -L zsh

zparseopts -D -K n=o_dryrun

function x {
   print "# $argv"
   if (($#o_dryrun)); then
     return
   fi
   "$@"
}

realScriptFn=$(readlink -f $0)
thisDir=$realScriptFn:h

x sudo cp -v $thisDir/yum.repos.d/*.repo /etc/yum.repos.d
