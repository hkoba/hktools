#!/bin/zsh

set -e

thisDir=$(cd $0:h && print $PWD)
source $thisDir:h/config.env


zparseopts -D -K n=o_dryrun

x sudo perl -i -pe 's/^(\s*issue_discards) = \d+/$1 = 1/' /etc/lvm/lvm.conf

x sudo perl -i -pe 's/^(GRUB_CMDLINE_LINUX=.*?) (rd.luks.uuid=)/$1 luks.options=discard rd.luks.options=discard $2/' /etc/default/grub

x sudo perl -i -alpe '$_ = join(" ", @F[0..2], "luks,discard")' /etc/crypttab

x sudo dracut -f

x sudo grub2-mkconfig -o /etc/grub2-efi.cfg

x sudo shutdown -r now

# 動作を確認するには sudo fstrim /
