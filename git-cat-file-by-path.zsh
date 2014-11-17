#!/bin/zsh

set -eu

((ARGC >= 2)) || {
    echo 1>&2 "Usage: ${0:t} <tree-ish> <path>"
    return 1
}

git ls-tree $argv | read -A line

git cat-file -p $line[3]
