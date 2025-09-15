#!/usr/bin/tclsh

package require fileutil

set ::conpromisedDict {
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

proc report {package version} {
    if {![dict exists $::conpromisedDict $package]} return
    set ngVer [dict get $::conpromisedDict $package]
    set vcomp [package vcompare $version $ngVer]
    if {$vcomp == 0} {
        return [list NG $package]
    } else {
        set msg [expr {$vcomp > 0 ? "newer" : "older"}]
        return [list ok $package "$version: $msg than $ngVer"]
    }
}

if {[catch {
    package require rl_json
    namespace import rl_json::*
}]} {
    
    set pipe [open [list | find -name package.json | xargs jq -r {[.name, .version] | @tsv}]]

    while {[gets $pipe line] >= 0} {
        if {![llength $line]} continue
        # puts stderr "# $line"
        lassign $line package version
        set diag [report $package $version]
        if {$diag ne ""} {
            puts $diag
        }
    }


} else {
    set pipe [open [list | find -name package.json]]

    array set stats [list ok 0 NG 0]

    while {[gets $pipe fn] >= 0} {
        set json [fileutil::cat $fn]
        set diag ""
        try {
            if {![json exists $json name] || ![json exists $json version]} continue
            set package [json get $json name]
            set version [json get $json version]
            if {[set diag [report $package $version]] ne ""} {
                puts $diag\t$fn
            }

            incr stats([lindex $diag 0])

        } on error err {
            puts "ERR $err\t$fn"
        }
    }

    puts ""
    foreach k {ok NG} {
        puts "$k $stats($k)"
    }
}

if {$pipe ne ""} {
    close $pipe
}
