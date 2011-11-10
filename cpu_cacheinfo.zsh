#!/bin/zsh

sysfs=/sys/devices/system/cpu
cpu=cpu0

function read_var_from {
    local from=$1 var=$2
    typeset -x "cacheinfo[$var]"=$(< $from/$var)
}

keys=(
    coherency_line_size
    number_of_sets
    ways_of_associativity
    level
    type
    size
)

typeset -A cacheinfo

grep '^model name' /proc/cpuinfo|head -1

for n in $sysfs/$cpu/cache/index<0->; do
    cacheinfo=()
    for v in $keys; do
	read_var_from $n $v
    done
    print -n L$cacheinfo[level]-$cacheinfo[type]
    print -n " " $cacheinfo[size] " = "
    print -n $cacheinfo[number_of_sets]sets "* "
    print -n $cacheinfo[ways_of_associativity]ways "* "
    print -n $cacheinfo[coherency_line_size]bytes/line
    print
done
