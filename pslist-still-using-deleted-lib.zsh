#!/bin/zsh

set -eu
progname=$0:t

function die { echo 1>&2 $*; exit 1 }
function usage {
	cat 1>&2 <<-EOF
	Usage: $progname libname
	EOF
	exit 1
}

((ARGC)) || usage "Not enough argument"
libname=$1

typeset -A dup; dup=()
grep $libname /proc/*/maps|grep deleted|while read fn rest; do
  pid=${${fn#/proc/}//\/*/}
  ((dup[$pid]++)) && continue
  echo -n $pid " "; readlink /proc/$pid/exe
done
