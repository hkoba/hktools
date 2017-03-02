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

o_xtrace=()
zparseopts -D -K x=o_xtrace

#========================================

((ARGC == 2)) || usage

askpass=/usr/libexec/openssh/gnome-ssh-askpass

host=$1
user=$2

authFn=/home/$user/.ssh/authorized_keys

cmds=(
    "useradd -s /bin/zsh $user"
    "usermod -aG adm $user"
    "usermod -aG wheel $user"
    "install -d -o $user -g $user -m 2700 ${authFn:h}"
    "tee -a $authFn"
    "chown $user:$user $authFn"
    "chmod 0600 $authFn"
)

ssh_cmd=(
    env SUDO_ASKPASS=$askpass
    sudo
    sh $o_xtrace -c "${(qqj/&&/)cmds}"
)

# set -x
# print -lR ssh $host "${ssh_cmd}"

sudo cat /home/$user/.ssh/authorized_keys |
ssh $host "$ssh_cmd"
