#!/bin/zsh

emulate -L zsh
set -e
function die { echo 1>&2 $*; exit 1 }

binDir=$(cd $0:h && print $PWD)
phaseName=$binDir:t

((ARGC)) || die "Usage: $0 DESTDIR"

destDir=$1; shift

[[ -d $destDir ]] || mkdir -p $destDir

destFn=$destDir/$phaseName.rpmlst

rpm -qa --qf '%{VENDOR}\t%{NAME}\n' |
    perl -nle 'next if /^\S+?-debuginfo\t/; print' |
    sort | uniq > $destFn

echo EXPORTED: $destFn

