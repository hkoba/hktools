#!/bin/zsh

path+=($0:h)
rehash

function warn { print -- 1>&2 $* }
function die { warn $*; exit 1 }

function usage {
    (($#argv)) && warn $argv
    cat 1>&2 <<EOF; exit 1
Usage: ${0:t} DESTDIR  SRC-LVM...
EOF
}

utilcmd=lvsnapclone.zsh
(($+commands[$utilcmd])) || die "Can't find $utilcmd in path"

zparseopts -D n=o_dryrun v=o_verbose x=o_xtrace || usage
opts=(
    $o_dryrun $o_verbose $o_xtrace
)

((ARGC >= 2)) || usage

dest=$1; shift
[[ $dest[-1] == '/' ]] || dest+='/'

arglist=()
for lv in $*; do
    arglist+=($lv $dest)
done

$utilcmd $opts $arglist
