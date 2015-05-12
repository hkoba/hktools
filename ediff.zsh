#!/bin/zsh

source $0:h/zfuncs/elisp.func

((ARGC == 2)) || die Usage: $0:t FILE1 FILE2

elisp=(
    ssri-ediff-files $(quot_list $(pwd_list "$@"))
)

# 何故か、yatt な html だと buffer is out of sync が出てエラーに。

set -x
emacsclient --eval "$(paren_list $elisp)"
