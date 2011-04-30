#!/bin/zsh

# lvsnapclone.zsh src1 dest1 src2 dest2 ...
# note: destination is not limited to lv.

set -e

function die { echo 1>&2 $*; exit 1 }
((ARGC >= 2 && ARGC % 2 == 0)) ||
die "Usage: ${0##/*} src-lv dest src2 dest2..."

snap=()
src=()
typeset -A dest

#
# Side effect: size_gig, size_sector
#
function size_gig {
    local src=$1

    size_sector=${${(s/:/)$(lvdisplay -c $src)}[7]} ||
    die "Can't find LV size of $src"
    size_gig=$[size_sector/2048/1024]
}

{
    # 1st. Prepare all snapshot and destination.
    for s d in $*; do
	size_gig $s

	# XXX: snapshot size option.
	t=snap$#snap
	lvcreate --snapshot --name $t -L2G $s
	snap+=($s:h/$t)

	lvcreate --name $d:t --size ${size_gig}G $d:h

	dest[$snap[-1]]=$d

	src+=($s)
    done

    # 2nd. Copy snapshot to destination.
    for t in $snap; do
	# XXX: time/nice option.
	time dd if=$t of=$dest[$t] conv=sync,noerror bs=1M
    done

} always {
    lvremove -f $snap
}

# ./lvsnapclone.zsh /dev/vghk08/fc6root /dev/vghk08/fc6root-bak /dev/vghk08/fc6var /dev/vghk08/fc6var-bak
