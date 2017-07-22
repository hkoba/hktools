#!/bin/zsh

source $0:h:h/config.env
thisDir=$(cd $0:h && print $PWD)

zparseopts -D -K n=o_dryrun

((ARGC)) || die "Usage: $0 [-n] HOST"

destHost=$1; shift

repos=(
    $toolRootDir
    $toolRootDir:h/mindots
    $toolRootDir:h/products
)

rsync=()
for r in $repos; do
    [[ -d $r ]] || continue
    rsync+=($r)
done

x rsync -az $rsync $destHost:

echo DONE
