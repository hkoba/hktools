#!/bin/zsh

function die { echo 1>&2 $*; exit 1 }
function bailout { die setup failed }

dir=$(dirname $0)

cp -vu $dir/dot.gitignore /etc/.gitignore || bailout

cd /etc || bailout

if [[ -d .git ]]; then
  echo /etc already has .git, skipped.
else
  git init --shared=0600
fi
