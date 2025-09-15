#!/usr/bin/tclsh

set conpromisedDict {
backslash	0.2.1
chalk-template	1.1.1
supports-hyperlinks	4.1.1
has-ansi	6.0.1
simple-swizzle	0.2.3
color-string	2.1.1
error-ex	1.3.3
color-name	2.0.1
is-arrayish	0.3.3
slice-ansi	7.1.1
color-convert	3.1.1
wrap-ansi	9.0.1
ansi-regex	6.2.1
supports-color	10.2.1
strip-ansi	7.1.1
chalk	5.6.1
debug	4.4.2
ansi-styles	6.2.2
}

set pipe [open [list | find -name package.json | xargs jq -r {[.name, .version] | @tsv}]]

while {[gets $pipe line] >= 0} {
    if {![llength $line]} continue
    # puts stderr "# $line"
    lassign $line package version
    if {![dict exists $conpromisedDict $package]} continue
    if {[set ngVer [dict get $conpromisedDict $package]] eq $version} {
        puts "NG $package"
    } else {
        puts "ok $package ($ngVer <=> $version: [package vcompare $ngVer $version])"
    }
}

close $pipe
