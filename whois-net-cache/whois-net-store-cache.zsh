#!/bin/zsh

binDir=$(cd $0:h && print $PWD)

function die { echo 1>&2 $*; exit 1 }

zparseopts h:=o_host
((ARGC)) || die "Usage: ${0:t} [-h HOST] IPADDR"

ipaddr=$1; shift

() {
    local tmpFn=$1
    if range=$($binDir/extract-field-from-whois.pl -a $tmpFn); then
	mv -vu $tmpFn $($binDir/iprange.pl $range).whois.out
    else
	echo 1>&2 "whois response doesn't have (a. [Network Number])"
	# cat 1>&2 $tmpFn
	exit 1
    fi
} =(whois $o_host "NET $ipaddr")
