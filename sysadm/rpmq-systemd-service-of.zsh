#!/bin/zsh

for fn in $*; do
    rpm -ql $(rpm -qf $fn) | grep '^/usr/lib/systemd' | grep '\.service$' |
    while read svcfn; do
	svc=$svcfn:t
	# systemctl --quiet is-enabled $svc || continue
	systemctl --quiet is-active $svc || continue
	print $svc
    done
done
