#!/bin/zsh

source $0:h:h/config.env
thisDir=$(cd $0:h && print $PWD)

zparseopts -D -K n=o_dryrun
if (($#o_dryrun)); then
    die "Dryrun is not yet supported."
fi

((ARGC)) || die "Usage: $0 HOST"

destHost=$1; shift

$toolRootDir/sysadm/yum-repos.zsh $(< $thisDir/ignored.lst) | 
ssh $destHost $sudo_auth sudo -A tar -xv -C /etc/yum.repos.d -f -
