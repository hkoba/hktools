#!/bin/zsh

path+=($0:h)
rehash

function die { echo 1>&2 $*; exit 1 }

retry=(-c 3)

zparseopts -D -K n=dryrun v=verbose x=xtrace -title:=title c:=retry || exit 1

if ! ((ARGC)); then
    die Usage: $0:t 'rootdev=newdev' '?more_devs=more_new_devs...?'
fi

[[ -x $0:h/lvsnapclone.zsh ]] || die "Can't find lvsnapclone.zsh"

set -e

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

grubby --info=/boot/vmlinuz-$(uname -r) | source /dev/fd/0

if (($+commands[dracut])); then
    mkinitrd=()
    initramfs=$initrd
else
    initramfs=$initrd:r-new.img
    mkinitrd=(-f --fstab=$mnt_tmp/etc/fstab $initramfs $(uname -r))
fi

print -r lvsnapclone.zsh $clone_list
print -r orig_devs $orig_devs
print -r new_devs $new_devs
print -r sed_args $sed_args
print -r mnt_tmp $mnt_tmp

grubby=(
    --title=${title[2][2,-1]:-New clone $new_devs[1]} 
    --make-default --copy-default 
    --initrd=$initramfs --add-kernel=/boot/$kernel
    --args="root=$new_devs[1]"
)

print -r grubby ${(q)grubby}

if [[ -n $dryrun ]]; then
    exit
fi

if [[ -n $xtrace ]]; then
    set -x
fi

mkdir $mnt_tmp

{

    lvsnapclone.zsh $retry $clone_list ||
    read -q "yn?lvsnapclone might failed. proceed? [y/n] "

    mount $new_devs[1] $mnt_tmp || read -q "yn?mount failed. proceed? [y/n] "

    sed -i $sed_args $mnt_tmp/etc/fstab

    if (($#mkinitrd)); then mkinitrd $mkinitrd; fi

    umount $mnt_tmp

    grubby $grubby

} always {
    rmdir $mnt_tmp
}
