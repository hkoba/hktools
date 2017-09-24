#!/bin/zsh

emulate -L zsh

binDir=$(cd $0:h && print $PWD)
dataDir=$binDir/$0:r:t.d

setopt extendedglob

for fn in $dataDir/<1->*.zsh(N); do
	$fn
done

#cmd=notify-send
#if [[ ! -t 0 && ! -t 1 ]] && (($+commands[$cmd])); then
	#$cmd OK "myautostart finished"
#fi
