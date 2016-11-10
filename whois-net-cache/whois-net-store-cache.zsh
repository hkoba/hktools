#!/bin/zsh

binDir=$(cd $0:h && print $PWD)

function die { echo 1>&2 $*; exit 1 }

zparseopts -D -K x=o_xtrace h:=o_host
((ARGC)) || die "Usage: ${0:t} [-h HOST] IPADDR"

((!$#o_xtrace)) || set -x

ipaddr=$1; shift

cp_opts=(-vu --no-preserve=all)

() {
    local tmpFn=$1
    if range=$($binDir/extract-field-from-whois.pl -a $tmpFn); then
	cp $cp_opts $tmpFn $($binDir/iprange.pl $range).whois.out
    else
	echo 1>&2 "whois response doesn't have (a. [Network Number])"
	cp $cp_opts $tmpFn $ipaddr.whois.ng
	# cat 1>&2 $tmpFn
	exit 1
    fi
} =(whois $o_host "NET $ipaddr")
