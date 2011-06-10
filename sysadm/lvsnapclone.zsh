#!/bin/zsh

# lvsnapclone.zsh src1 dest1 src2 dest2 ...
# note: destination is not limited to lv.

set -e

function die { echo 1>&2 $*; exit 1 }

zparseopts -D n=dryrun x=xtrace c:=retry_count || exit 1

((ARGC >= 2 && ARGC % 2 == 0)) ||
die "Usage: [-n] [-v] [-x] ${0##/*} src-lv dest src2 dest2..."

function x {
    print -- "$@"
    if [[ -z $dryrun ]]; then
	"$@"
    fi
}

snapList=()
typeset -A srcDict
typeset -A destDict

#
# Side effect: size_gig, size_sector
#
function size_gig {
    local src=$1

    size_sector=${${(s/:/)$(lvdisplay -c $src)}[7]} ||
    die "Can't find LV size of $src"
    size_gig=$[size_sector/2048/1024]
}

if [[ -n $xtrace ]]; then
    set -x
fi

{
    # 1st. Prepare all snapshot and destination.
    for s d in $*; do
	size_gig $s

	# XXX: snapshot size option.
	t=snap$#snap
	snap=$s:h/$t
	snapList+=($snap)

	x lvcreate --name $d:t --size ${size_gig}G $d:h

	destDict[$snap]=$d
	srcDict[$snap]=$s
    done

    # 2nd. Create snapshots.
    for snap in $snapList; do
	x lvcreate --snapshot --name $snap:t -L2G $srcDict[$snap]
    done
	
    # 3rd. Copy snapshot to destination.
    for t in $snapList; do
	# XXX: time/nice option.
	x dd if=$t of=$destDict[$t] conv=sync,noerror bs=1M
	# XXX: this assumes ext2/3/4
	x tune2fs -U $(uuidgen) $destDict[$t]
	if ! x lvremove -f $t && (($#retry_count)); then
	    for ((i=1; i <= $retry_count[-1]; i++)); do
		lvremove -f $t && break
	    done
	fi
    done

} always {
    # x lvremove -f $snapList
}

# ./lvsnapclone.zsh /dev/vghk08/fc6root /dev/vghk08/fc6root-bak /dev/vghk08/fc6var /dev/vghk08/fc6var-bak
