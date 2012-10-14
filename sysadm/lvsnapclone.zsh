#!/bin/zsh

# lvsnapclone.zsh src1 dest1 src2 dest2 ...
# note: destination is not limited to lv.

set -e

setopt extendedglob numericglobsort

function die { echo 1>&2 $*; exit 1 }

zparseopts -D n=dryrun x=xtrace c:=retry_count || exit 1

((ARGC >= 2 && ARGC % 2 == 0)) ||
die "Usage: [-n] [-v] [-x] ${0##/*} src-lv dest src2 dest2..."

# To avoid lvm warnings of leaked fd.
function close_leaked_special_fds {
    local fd
    integer fdno;
    for fd in /dev/fd/<3->(N); do
	[[ -f $fd ]] && continue
	fdno=$fd:t;
	exec {fdno}<&- || true
    done
    # local remains
    # remains=(/dev/fd/<3->(N))
    # print remains: ${${^remains}:t}
}
close_leaked_special_fds

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

function is_lvm_path {
    local fn=$1 vgName=$2 lvName=$3
    [[ $fn == /dev/* ]] || return 1
    fnsegs=(${(s,/,)fn});
    (($#fnsegs <= 3)) || return 1
    shift fnsegs; # drop /dev/
    local vg_lv mapper
    if [[ $fnsegs[1] == mapper ]]; then
	mapper=$fnsegs[2]
	vg_lv=(${$mapper%%-*})
	vg_lv+=(${${mapper}[$#vg_lv[1]+2,-1]})
    else
	vg_lv=($fnsegs)
    fi

    (($+knownVG)) || load_knownVG
    (($+knownVG[$vg_lv[1]])) || return 1

    if [[ -n $vgName ]]; then
	typeset -x "$vgName=$vg_lv[1]"
    fi
    if [[ -n $lvName ]]; then
	typeset -x "$lvName=$vg_lv[2]"
    fi
    return 0
}
function load_knownVG {
    typeset -xA knownVG
    knownVG=($(vgs --noheadings -o vg_name,vg_uuid))
}
load_knownVG

{
    # 1st. Prepare all snapshot and destination.
    for s d in $*; do
	size_gig $s

	# XXX: snapshot size option.
	t=snap$#snapList
	snap=$s:h/$t
	snapList+=($snap)

	if is_lvm_path $d destvg destname; then
	    if [[ -z $destname ]]; then
		[[ $destvg == $s:h ]] || die "Can't use same lvname in $destvg and ${s:h}"
		destname=$s:t
	    fi
	    x lvcreate --name $destname --size ${size_gig}G $destvg
	elif [[ $d == */ ]]; then
	    # If $d is non-lvm and $d end with "/", use src volname.
	    d+=$s:t
	fi

	destDict[$snap]=$d
	srcDict[$snap]=$s
    done

    # 2nd. Create snapshots.
    for snap in $snapList; do
	sync
	x lvcreate --snapshot --name $snap:t -L2G $srcDict[$snap]
    done
	
    # 3rd. Copy snapshot to destination.
    for t in $snapList; do
	# XXX: time/nice option.
	# XXX: make background and progress watching by kill -USR1
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
