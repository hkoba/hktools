#!/bin/zsh

set -eu

config=/etc/sysconfig/iptables
: ${TIMEOUT:=15}

function revert-unless-confirmed {
  local saved=$1

  echo Applying new rules...
  service iptables restart

  local ret="" read_opts=()
  if is-at-least 5.0; then
    read_opts+=(-q)
  fi
  {
     read $read_opts -t $TIMEOUT "ret?Can you establish NEW connections to the machine? (y/N) "
  } always {
     if (($? == 0)) && [[ $ret = y || $ret = Y ]]; then
       echo ok.
     else
       echo -n reverting...
       iptables-restore < $saved
       echo done
     fi
  }
}

revert-unless-confirmed =(iptables-save)
