#!/bin/zsh

emulate -L zsh

binDir=$(cd $0:h && print $PWD)
dataDir=$binDir/$0:r:t.d

setopt extendedglob

for fn in $dataDir/<1->*.zsh(N); do
	$fn
done
