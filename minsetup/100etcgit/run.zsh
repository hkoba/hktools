#!/bin/zsh

source $0:h:h/config.env
thisDir=$(cd $0:h && print $PWD)

zparseopts -D -K n=o_dryrun

((ARGC)) || die "Usage: $0 [-n] HOST"

destHost=$1; shift

echo "#" Copying $etcGitDir/ to $destHost
x rsync -Cavz $etcGitDir/ $destHost:$etcGitDir:t

echo "#" Installing /root/.zshenv "(for sudo GIT_AUTHOR_NAME)"
x ssh -t $destHost sudo cp -vu $etcGitDir:t/root.zshenv /root/.zshenv

echo "#" Setting up etcgit
x ssh -t $destHost sudo $etcGitDir:t/setup.zsh -c
