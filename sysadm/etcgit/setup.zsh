#!/bin/zsh

function die { echo 1>&2 $*; exit 1 }
function bailout { die setup failed }

emulate -L zsh

zparseopts -D -K c=o_commit

dir=$(cd $0:h && print $PWD)

cp -vu $dir/dot.gitignore /etc/.gitignore || bailout

cd /etc || bailout

if [[ -d .git ]]; then
  echo /etc already has .git, skipped.
else
  git init --shared=0600
  if (($#o_commit)); then
      git add -A
      git commit -m init
  fi
fi
