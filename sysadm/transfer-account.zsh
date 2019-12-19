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

o_xtrace=() o_sh=() o_install_prereqs=() o_admin=() o_group=()
o_gitconfig=()
zparseopts -D -K x=o_xtrace P=o_install_prereqs A=o_admin \
           -gitconfig=o_gitconfig \
           s:=o_sh \
           G:=o_group

if (($#o_xtrace)); then
  set -x
fi

if ((! $#o_sh)); then
    o_sh=(-s $SHELL)
fi

#========================================

((ARGC == 1 || ARGC == 2)) || usage

askpass=/usr/libexec/openssh/gnome-ssh-askpass
if [[ -n $DISPLAY && -x $askpass ]] && ((!$+SUDO_ASKPASS)); then
   export SUDO_ASKPASS=$askpass
fi

host=$1
user=${2:-$USER}

authFn=/home/$user/.ssh/authorized_keys

cmds=(
    "useradd $o_sh $user"
)
if (($#o_admin)); then
cmds+=(
    "usermod -aG adm $user"
    "usermod -aG wheel $user"
)
fi
if (($#o_group)); then
    for g in ${(s/,/)o_group[2]}; do
        cmds+=("usermod -aG $g $user")
    done
fi
cmds+=(
    "install -d -o $user -g $user -m 2700 ${authFn:h}"
    "tee -a $authFn"
    "chown $user:$user $authFn"
    "chmod 0600 $authFn"
)

function mk_ssh_cmd {
   local host=$1; shift
   local ssh_cmd=($host) cmds=("$@")

if [[ $host != root@* ]]; then
    ssh_cmd+=(
        env SUDO_ASKPASS=$askpass
        sudo
    )
fi
ssh_cmd+=(
    sh $o_xtrace -c "${(qqj/&&/)cmds}"
)

   print -R $ssh_cmd
}

# set -x
# print -lR ssh $host "${ssh_cmd}"

sudo_cat=()
if [[ $user != $USER ]]; then
    sudo_cat=(sudo)
fi

prereqs=(
  openssh-askpass
  xauth
  xorg-x11-fonts-Type1
)
if (($#o_install_prereqs)); then
  ssh $(mk_ssh_cmd $host "yum install $prereqs")
fi

echo Reading authorized_keys for $user...
authorized_keys=$($sudo_cat cat /home/$user/.ssh/authorized_keys)

echo Transfering account $user to $host...
#ssh -Y $host "$ssh_cmd" <<<$authorized_keys
ssh -Y $(mk_ssh_cmd $host "$cmds[@]") <<<$authorized_keys

echo Setting initial password for $user on $host...
pass=$($askpass Initial password for $user)
ssh -Y $(mk_ssh_cmd $host "passwd --stdin $user") <<<$pass

if (($#o_gitconfig)); then
    theFn=/home/$user/.gitconfig
    install_cmds=(
        "tee -a $theFn"
        "chown $user:$user $theFn"
    )
    
    {
        if [[ -r $theFn ]]; then
            cat $theFn
        else
            $sudo_cat cat $theFn
        fi
    } | ssh -Y $(mk_ssh_cmd $host "$install_cmds[@]")
fi

echo DONE
