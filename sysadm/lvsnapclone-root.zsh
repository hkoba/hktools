#!/bin/zsh

path+=($0:h)
rehash

autoload colors; colors

function die { echo 1>&2 $*; exit 1 }

zparseopts -D n=dryrun v=verbose x=xtrace -title:=title c:=retry || exit 1
if ! (($#retry)); then
	retry=(-c 3)
fi

if ! ((ARGC)); then
    die Usage: $0:t 'OLDrootLV=NEWrootLV' '[OLD_LV=NEW_LV]...'
fi

[[ -x $0:h/lvsnapclone.zsh ]] || die "Can't find lvsnapclone.zsh"

set -e

typeset -A lvmap
orig_devs=()
new_devs=()
clone_list=()
sed_args=()

function list_devs {
    local i dev orig new
    for i in $*; do
	dev=(${(s/=/)i})
	if (($#dev != 2)); then
	    die "Please specify olddev=newdev! $i"
	fi
	if [[ $dev[2]:h == '.' ]]; then
	    dev[2]=$dev[1]:h/$dev[2]
	fi
	lvmap[${dev[1]#/dev/}]=${dev[2]#/dev/}
	orig_devs+=($dev[1])
	new_devs+=($dev[2])
	clone_list+=($dev)

	if [[ $dev[1] == /dev/mapper/* ]]; then
	    orig="\\(/dev/${(j,/,)${(s,-,)${(s,/,)dev[1]}[-1]}}\\|$dev[1]\\)"
	else
	    orig="\\(/dev/mapper/${(j,-,)${(s,/,)dev[1]}[2,3]}\\|$dev[1]\\)"
	fi
	sed_args+=(-e  s,\^$orig,$dev[2],)
    done
}

list_devs $argv

if ! (($#clone_list)); then
    die "device list is empty"
fi

# root=(${(s/=/)1}); shift
# devs=($*)
# root_bak=$root-bak

mnt_tmp=/var/tmp/$0:t:r.$$

# initrd

typeset -A curboot
grubby --info=/boot/vmlinuz-$(uname -r) | while IFS='=' read key value; do
    # Since title can contain space, source /dev/fd/0 is not ok.
    # Q is unquoting, for args.
    curboot[$key]=${(Q)value}
done

#
# To replace dracut LVM rd.lvm.lv args (rd_LVM_LV should be replaced too??)
#
new_args=("root=$new_devs[1]")
if [[ -n $curboot[args] ]]; then
    for x in ${=curboot[args]}; do
	if [[ $x = root=* ]]; then
	    # skip
	elif [[ $x = rd.lvm.lv=* ]] &&
	    {
		lv=(${(s/=/)x}); (($+lvmap[$lv[2]]))
	    }; then
	    new_args+=($lv[1]=$lvmap[$lv[2]])
	else
	    new_args+=($x)
	fi
    done
fi

if (($+commands[dracut])); then
    mkinitrd=()
    initramfs=$curboot[initrd]
else
    initramfs=$curboot[initrd]:r-new.img
    mkinitrd=(-f --fstab=$mnt_tmp/etc/fstab $initramfs $(uname -r))
fi

print -r lvsnapclone.zsh $'\t' $clone_list
print -r lvmap ${(kv)lvmap}
print -r orig_devs $'\t' $orig_devs
print -r new_devs $'\t' $new_devs
print -r sed_args $'\t' $sed_args
print -r mnt_tmp $'\t' $mnt_tmp

grubby=(
    --title=${title[2][2,-1]:-New clone $new_devs[1]} 
    --make-default --copy-default 
    --initrd=$initramfs --add-kernel=$curboot[kernel]
    --args="$new_args"
)

print -r grubby ${(qqq)grubby}

if [[ -n $dryrun ]]; then
    exit
fi

if [[ -n $xtrace ]]; then
    set -x
fi

mkdir $mnt_tmp

{

    $0:h/lvsnapclone.zsh $retry $clone_list ||
    read -q "yn?lvsnapclone might failed. proceed? [y/n] "

    mount $new_devs[1] $mnt_tmp || read -q "yn?mount failed. proceed? [y/n] "

    sed -i $sed_args $mnt_tmp/etc/fstab

    if (($#mkinitrd)); then mkinitrd $mkinitrd; fi

    umount $mnt_tmp

    grubby $grubby

    echo $bg[green]DONE$bg[default]
} always {
    rmdir $mnt_tmp
}
