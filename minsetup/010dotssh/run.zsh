#!/bin/zsh

source $0:h:h/config.env
thisDir=$(cd $0:h && print $PWD)

set -e

zparseopts -D -K n=o_dryrun
if (($#o_dryrun)); then
    die "Dryrun is not yet supported."
fi

((ARGC)) || die "Usage: $0 HOST"

destHost=$1; shift

cd ~

tar cf - .ssh/{authorized_keys,id_rsa,id_rsa.pub,known_hosts} | 
ssh $destHost tar -xv -f -
