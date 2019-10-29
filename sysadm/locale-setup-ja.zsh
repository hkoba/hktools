#!/bin/zsh

emulate -L zsh

set -e

zparseopts -D -K n=o_dryrun

function x {
    if (($#o_dryrun)); then
        print -r "# " ${(q-)argv}
        return;
    fi
    "$@"
}

#----------------------------------------

forcecmds=(
    "dnf install 'dnf-command(langinstall)'"
)
cmds=(
    "echo '%_install_langs C:en:en_US:en_US.UTF-8:ja:ja_JP:ja_JP.UTF-8' > /etc/rpm/macros.image-language-conf"
    "dnf langinstall English Japanese"
    "dnf install glibc-all-langpacks perl"
    "cp /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl"
    "/usr/sbin/build-locale-archive"
    "dnf reinstall glibc-common filesystem glibc-all-langpacks"
    "locale -a | grep ja_JP"
    "perl -v"
)

all_cmd="${(j/;/)forcecmds};${(pj/ &&\n/)cmds}"

# $ssh -t $ssh_remote $use_sudo 

x sh -x -c "${(qq)all_cmd}"
