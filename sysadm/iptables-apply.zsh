#!/bin/zsh

config=/etc/sysconfig/iptables
: ${TIMEOUT:=15}

function revert-unless-confirmed {
  local saved=$1

  echo Applying new rules...
  service iptables restart

  {
     read -q -t $TIMEOUT "ret?Can you establish NEW connections to the machine? (y/N) "
  } always {
     if (($? == 0)); then
       echo ok.
     else
       echo -n reverting...
       iptables-restore < $saved
       echo done
     fi
  }
}

revert-unless-confirmed =(iptables-save)
