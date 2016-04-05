#!/bin/zsh

# lvsnapclone.zsh src1 dest1 src2 dest2 ...
# note: destination is not limited to lv.

set -e

setopt extendedglob numericglobsort

function die { echo 1>&2 $*; exit 1 }

progname=$0
function usage {
    if ((ARGC)); then
	print -- "$@" 1>&2
    fi
    cat 1>&2 <<EOF
Usage: ${progname:t} [OPTION]... SOURCE DEST  SRC2 DEST2...
Clone Logical Volume SOURCE to DEST, using LVM Snapshot.

Options:
-n        Dry run
-N        Use ionice
-U        Update UUID for known filesystems (currently ext2/3/4 only)
-P        Show dd progress using status=progress in dd
-S        Use conv=sparse in dd
EOF
    exit 1
}

opts=(
    n=dryrun
    x=xtrace
    v=verbose
    h=o_help

    U=o_update_uuid
    N=o_nice
    P=o_progress
    S=o_sparse

    '-preserve_snapshot=o_preserve_snapshot'

    'c:=retry_count'
)

zparseopts -D $opts || exit 1
# XXX: Unfortunately, zparseopts doesn't raise error.
((ARGC >= 2 && ARGC % 2 == 0)) || usage "Invalid arguments: $argv"
((! $#o_help)) || usage

missing_cmd=()
for cmd in lvdisplay lvcreate lvremove blkid dd; do
    (($+commands[$cmd])) || missing_cmd+=($cmd)
done
if (($#missing_cmd)); then
    die "Can't find $missing_cmd please install it first!"
fi

# To avoid lvm warnings of leaked fd.
function close_leaked_special_fds {
    local fd
    integer fdno;
    for fd in /dev/fd/<4->(N); do
	[[ -f $fd ]] && continue
	fdno=$fd:t;
	exec {fdno}<&- || true
    done
    # local remains
    # remains=(/dev/fd/<3->(N))
    # print remains: ${${^remains}:t}
}

close_leaked_special_fds 2>/dev/null

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

nice=()
if (($#o_nice)); then
    nice=(ionice)
fi

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

function after_clone_hook_for {
    local from=$1 clone=$2 fstype hook
    
    if [[ -e $from ]] &&
       fstype=$(blkid -p -u filesystem -s TYPE -o value $from) &&
       hook=after_clone_$fstype &&
       (($+functions[$hook])); then

	$hook $clone
    else
	# no hooks
    fi
}

function after_clone_ext2 { after_clone_ext234 "$@" }
function after_clone_ext3 { after_clone_ext234 "$@" }
function after_clone_ext4 { after_clone_ext234 "$@" }

function after_clone_ext234 {
    local clone=$1
	
    if (($#o_update_uuid)); then
	x tune2fs -U $(uuidgen) $clone
    fi
}

function remove_snaplist {
    if ((! $#o_preserve_snapshot && $#snapList)); then
	x lvremove -f $snapList
	snapList=()
    fi
}

{
    trap remove_snaplist INT

    # 1st. Prepare all destinations and determine snapshot path for them.
    # XXX: Total capacity checking for destination(s), before actual lvcreate.
    for s d in $*; do
	size_gig $s

	# XXX: snapshot size option.
	t=snap$#snapList
	snap=$s:h/$t

	if [[ -e $snap ]]; then
	    die "Snapshot $snap already exists! Precheck failed!"
	fi

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
	snapList+=($snap)
    done

    # 2nd. Create snapshots.
    for snap in $snapList; do
	sync
	x lvcreate --snapshot --name $snap:t -L2G $srcDict[$snap]
    done
	
    conv=(
	sync
	noerror
    )
    if (($#o_sparse)); then
	conv+=(sparse)
    fi

    iflags=()
    iflags+=(direct)

    oflags=()
    oflags+=(nocache)

    dd_opts=(
	conv=${(j/,/)conv}
	bs=64K
    )
    ((! $#iflags)) || dd_opts+=(iflag=${(j/,/)iflags})
    ((! $#oflags)) || dd_opts+=(oflag=${(j/,/)oflags})

    if (($#o_progress)); then
	# XXX: Requires recent dd
	dd_opts+=(status=progress)
    fi

    # 3rd. Copy snapshot to destination.
    for t in $snapList; do
	# XXX: time option.
	# XXX: make background and progress watching by kill -USR1
	x $nice dd if=$t of=$destDict[$t] $dd_opts ||
	    break

	after_clone_hook_for $srcDict[$t] $destDict[$t]

	x lvremove -f $t

	shift snapList
    done

} always {

    remove_snaplist

    if ((TRY_BLOCK_ERROR)); then
	exit $TRY_BLOCK_ERROR
    fi
}

if (($#o_preserve_snapshot && $#snapList)); then
    print -l $snapList
fi

# ./lvsnapclone.zsh /dev/vghk08/fc6root /dev/vghk08/fc6root-bak /dev/vghk08/fc6var /dev/vghk08/fc6var-bak
