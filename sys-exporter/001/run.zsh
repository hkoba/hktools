#!/bin/zsh

emulate -L zsh
set -e
function die { echo 1>&2 $*; exit 1 }

binDir=$(cd $0:h && print $PWD)
toolRootDir=$binDir:h:h
admToolDir=$toolRootDir/sysadm
phaseName=$binDir:t

((ARGC)) || die "Usage: $0 DESTDIR"

destDir=$1; shift

[[ -d $destDir ]] || mkdir -p $destDir

destFn=$destDir/$phaseName.yum-repos.tar

$admToolDir/yum-repos.zsh -o $destDir/$phaseName.yum-repos.tar

echo EXPORTED: $destFn

