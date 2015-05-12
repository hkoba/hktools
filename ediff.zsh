#!/bin/zsh

source $0:h/zfuncs/elisp.func

((ARGC == 2)) || die Usage: $0:t FILE1 FILE2

files=()
for fn in $argv; do
    files+=($(paren_list find-file-noselect \"$(pwd_list $fn)\"))
done

set -x
emacsclient --eval "$(paren_list ediff-buffers $files)"
