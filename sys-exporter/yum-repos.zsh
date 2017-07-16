#!/bin/zsh
#
# This command exports non-core yum-repos as TAR format(non compressed).
#

emulate -L zsh
set -e

o_outfn=(-o -)
zparseopts -D -K v=o_verbose o:=o_outfn

cd /etc/yum.repos.d

repos=()
for fn in *.repo; do
    rpm -qf $fn >&/dev/null && continue
    repos+=($fn)
done

tar cf $o_outfn[2] $o_verbose $repos
