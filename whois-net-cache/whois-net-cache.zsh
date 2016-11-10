#!/bin/zsh

set -e

zparseopts -D -K h:=o_host

binDir=$(cd $0:h && print $PWD)

sleep=40

for ip in "$@"; do
    if [[ -e $ip.whois.ng ]]; then
        echo $ip is not known.
    elif $binDir/whois-net-fetch-cache.zsh $ip; then
        echo $ip is cached.
    else
        echo Fetching $ip ...
        $binDir/whois-net-store-cache.zsh $o_host $ip || true
        echo -n sleeping ${sleep} seconds...
        sleep $sleep;
    fi
done
