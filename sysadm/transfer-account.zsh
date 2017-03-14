#!/bin/zsh

emulate -L zsh

set -eu

scriptName=$0

function die { echo 1>&2 $*; exit 1 }
function usage {
    cat 1>&2 <<EOF
Usage: ${scriptName:t} HOST USER
EOF
    exit 1
}

#========================================

o_xtrace=() o_sh=()
zparseopts -D -K x=o_xtrace s:=o_sh

#========================================

((ARGC == 1 || ARGC == 2)) || usage

askpass=/usr/libexec/openssh/gnome-ssh-askpass

host=$1
user=${2:-$USER}

authFn=/home/$user/.ssh/authorized_keys

cmds=(
    "useradd $o_sh $user"
    "usermod -aG adm $user"
    "usermod -aG wheel $user"
    "install -d -o $user -g $user -m 2700 ${authFn:h}"
    "tee -a $authFn"
    "chown $user:$user $authFn"
    "chmod 0600 $authFn"
)

ssh_cmd=()
if [[ $host != root@* ]]; then
    ssh_cmd+=(
        env SUDO_ASKPASS=$askpass
        sudo
    )
fi
ssh_cmd+=(
    sh $o_xtrace -c "${(qqj/&&/)cmds}"
)

# set -x
# print -lR ssh $host "${ssh_cmd}"

sudo_cat=()
if [[ $user != $USER ]]; then
    sudo_cat=(sudo)
fi

$sudo_cat cat /home/$user/.ssh/authorized_keys |
ssh $host "$ssh_cmd"
