#!/bin/zsh

set -e

zparseopts -D -K n=o_dryrun || exit 1

function x {
    print -- "$@"
    if (($#o_dryrun)); then return; fi
    "$@"
}

zmodload zsh/stat

for d in $argv; do
    u=$(zstat -s +uid $d) || continue
    x su $u -c "cd $d && git gc --aggressive" || break
    if [[ -e $d/.gitmodules ]]; then
	x su $u -c "cd $d && git submodule foreach git gc --aggressive" || break
    fi
done
