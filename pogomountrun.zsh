#!/bin/zsh

progfile=$0
mnt=~/Pogoplug

function usage {
    cat <<EOF
Usage: ${progfile:t} [-v] COMMAND args...

 This command starts pogoplugfs --mountpoint $mnt,
 wait it becomes ready and run specified COMMAND
 (or your \$SHELL, if not specified).

 When your command terminated, pogoplugfs is automatically terminated too.
EOF
    exit
}

blk='\[[.[:alnum:]]##\]'
header="$blk$blk$blk$blk "

setopt extendedglob; # This is very important!

function die { echo 1>&2 $*; exit 1 }

function bailout {
    zpty -d pogo
    die "$@"
}

function pogo_expect {
    ((ARGC)) || die pogo_expect needs PATTERN

    local pattern=$1; shift
    integer ok=0
    local line msg
    if (($#o_verbose)); then
	print "Waiting: $pattern"
    fi
    while zpty -r pogo line; do
	if (($#o_verbose)); then
	    print -n $line
	fi
	msg=${line#$~header}
	if [[ $msg == $~pattern ]]; then
	    ok=1
	    if (($#o_verbose)); then
		print "Found!"
	    fi
	    break
	elif (($#o_verbose)); then
	    print "Not matched: msg=$msg"
	fi
    done
    ((ok))
}

function wait_pty_is_blocking {
    local pty=$1 line;
    while zpty -r -t $pty line; do
	if (($#o_verbose)); then
	    print $line
	fi
	true
    done
}

function msleep {
    zmodload zsh/zselect
    # Note: in zselect, TIMEOUT 1 means 1/100 sec, not msec!
    zselect -t $1
    true
}

function pogo_wait_mounted {
    local mnt=$1 hsec=${2:-30}
    local lines
    lines=($(ls -1 $mnt))
    (($#lines)) && return
    print -n Waiting.
    while msleep $hsec; do
	lines=($(ls -1 $mnt))
	(($#lines)) && break
	print -n .
    done
    print OK
}

#========================================
zparseopts -D v=o_verbose h=o_help m:=o_mnt

(($#o_help)) && usage

(($+commands[pogoplugfs])) || die "Can't find pogoplugfs command!"

if (($#o_mnt)); then
    mnt=$o_mnt[-1]
fi

[[ -d $mnt ]] || die "mountpoint $mnt does not exist!"

config_exists=0
for fn in $PWD/pogoplugfs.conf ~/.pogoplugfs.conf /etc/pogoplugfs.conf; do
    [[ -r $fn ]] || continue
    config_exists=1; break
done

((config_exists)) || die "pogoplugfs.conf is missing!"

# XXX: Use of zpty might be too much. zsh coproc may capable.
zmodload zsh/zpty
zpty pogo pogoplugfs --mountpoint $mnt
zpty -t pogo || die "Can't invoke pogoplugfs"

pogo_expect "Logged in as *" || bailout "Can't detect login message"

wait_pty_is_blocking pogo

pogo_wait_mounted $mnt

print "=== Mount point $mnt ===";
ls -l $mnt
print

if ((ARGC)); then
    "$@"
else
    $SHELL
fi

sync

until fusermount -u $mnt; do
  print "sleeping to retry umount..."; sleep 1;
done

pogo_expect "Fuse loop exited*"

wait_pty_is_blocking pogo
