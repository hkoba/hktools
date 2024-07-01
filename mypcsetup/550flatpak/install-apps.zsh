#!/bin/zsh

#----------------------------------------
# Reset options
# zsh の動作オプションを揃える

emulate -L zsh

# set -eu

# setopt YOUR_FAVORITE_OPTIONS_HERE

setopt extended_glob

#----------------------------------------
# Set variables for application directory
# スクリプトをインストール個所に依存させないための変数を用意

# $0            = ~/bin/mytask
# $realScriptFn = /somewhere/myapp/bin/myscript.zsh
# binDir        = /somewhere/myapp/bin
# appDir        = /somewhere/myapp

realScriptFn=$(readlink -f $0); # macOS/BSD の人はここを変更
binDir=$realScriptFn:h
appDir=$binDir:h

#----------------------------------------
# Read application configuration(using anonymous function block to have local variable)
# 設定は zsh の変数代入で
# なお zsh の source には引数を渡せるので、ここで何かを渡す手もある。

() {
    local fn
    for fn in $*; do
        if [[ -r $fn ]]; then source $fn; fi
    done
} $appDir/config.zenv

#----------------------------------------
# Parse primary options
# オプションの解析

o_yes=()
o_dryrun=() o_quiet=() o_xtrace=() o_help=()

zparseopts -D -K \
           y=o_yes \
           n=o_dryrun -dry-run=o_dryrun \
           q=o_quiet -quiet=o_quiet \
           x=o_xtrace \
           h=o_help      -help=o_help

if (($#o_xtrace)); then set -x; fi

#----------------------------------------
# Utility functions
# いつも使う関数をここで。(source しても良い)

function x {
    if (($#o_dryrun || !$#o_quiet)); then
        print -R '#' ${(q-)argv}
    fi
    if (($#o_dryrun)); then
        return;
    fi
    "$@" || exit $?
}

function die { echo 1>&2 $*; exit 1 }

#----------------------------------------


appList=($(flatpak list --app --columns=application))

wantList=($binDir/appids/*(N:t))

for app in $wantList; do
    (($appList[(ri)$app] <= $#appList)) && continue
    repo=$(< $binDir/appids/$app)
    x sudo flatpak install $o_yes $repo $app
done
