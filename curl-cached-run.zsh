#!/bin/zsh

set -e; # err_exit

progname=$0:t

function die { print 1>&2 $*; exit 1 }
function usage {
    cat 1>&2 <<EOF; exit 1
Usage: $progname URL command args...

run 'command args...' when URL is newer file is downloaded.
EOF
}

#========================================
opts=(--fail)

zparseopts -D -K x=o_xtrace n=o_dryrun v=o_verbose || usage

if (($#o_xtrace)); then
    set -x
fi

if ! (($#o_verbose)); then
    opts+=(--silent)
fi

((ARGC)) || usage

#========================================

url=$1; shift
then_cmd=("$argv[@]")

savename=$url:t
saveopt=(-O)
# XXX: Fail if url contains query-string...
# XXX: Fail if url ends with '/'...

function run {
    if (($#o_verbose)); then
	print -r -- $*
    fi
    if (($#o_dryrun)); then
	return
    fi
    if ((ARGC)); then
	"$@"
    fi
}

#========================================
zmodload zsh/stat

if [[ -e $savename ]]; then
    # zstat returns stat into hash variable $old_stat[].
    zstat -H old_stat $savename
fi

run curl $opts $saveopt -z $savename $url || die "Can't fetch $url"

if [[ -e $savename ]]; then
    zstat -H new_stat $savename
    if ((!$+old_stat)) || (($old_stat[mtime] != $new_stat[mtime])); then
	run $then_cmd
    fi
fi
