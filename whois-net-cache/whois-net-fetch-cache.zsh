#!/bin/zsh

binDir=$(cd $0:h && print $PWD)

function die { echo 1>&2 $*; exit 1 }
((ARGC)) || die "Usage: $0 IP"

ipaddr=$1; shift

cached=$($binDir/iplook-in-dir.pl . $ipaddr) || return 1
$binDir/extract-field-from-whois.pl -g $cached
