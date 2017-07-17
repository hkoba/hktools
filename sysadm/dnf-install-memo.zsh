#!/bin/zsh

emulate -L zsh

set -e

#----------------------------------------

zparseopts -D -K x=o_xtrace h=o_help

((!$#o_xtrace)) || set -x

((!$#o_help)) || {
    cat 1>&2 <<EOF
Usage: ${0:t} PACKAGE_NAMES...

Install packages and then memo their names into your
"~/.install-memo/\$epoch.lst".
EOF
    exit
}

#----------------------------------------

optList=()
pkgList=()

while ((ARGC)) && [[ $1 == -* ]]; do
    optList+=($1); shift
done
                        
if ((ARGC)) && [[ $1 == install ]]; then
    shift;
fi

pkgList=($argv)

#----------------------------------------

dnf $optList install $pkgList || exit 1

#----------------------------------------

need_chown=()
if (($+SUDO_USER)); then
    memoDir=~$SUDO_USER/.install-memo
    need_chown+=($memoDir)
else
    memoDir=~/.install-memo
fi

[[ -d $memoDir ]] || mkdir -p $memoDir

destFn=$memoDir/$(date +%s).lst

((! $+SUDO_USER)) || need_chown+=($destFn)

print -l -- $pkgList > $destFn

if (($#need_chown)); then
    chown $SUDO_USER:$SUDO_USER $need_chown
fi

echo MEMO: $destFn
