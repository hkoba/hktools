#!/usr/bin/tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

package require Tcl 8.6
package require snit

snit::type git-remote-editor {
    option -dir ""
    option -mapfile ""
    option -src-prefix ""
    option -dest-prefix ""

    method gui args {
        package require Tk
        ${type}::gui .win -target $self {*}$args
        pack .win -fill both -expand yes
    }

    method cmd-url-list {{remote origin} {DIR ""}} {
        foreach item [$self url-list $remote $DIR] {
            puts [join $item \t]
        }
    }
    method url-list {{remote origin} {DIR ""}} {
        set DIR [$self DIR $DIR]
        set result [list [list $DIR [$self git remote-url $remote $DIR]]]
        foreach sub [$self list $DIR] {
            lappend result [list $sub [$self git remote-url $remote $sub]]
        }
        set result
    }

    method {git remote-url} {{remote origin} {DIR ""}} {
        set DIR [$self DIR $DIR]
        exec git -C $DIR config remote.$remote.url
    }

    method list {{DIR ""}} {
        set DIR [$self DIR $DIR]
        set result []
        foreach sub [$self submodule list $DIR] {
            lappend result $sub {*}[lmap i [$self list $DIR/$sub] {
                string cat $DIR/$sub/$i
            }]
        }
        set result
    }

    method {submodule list} {{DIR ""}} {
        lmap i [$self submodule detail $DIR] {lindex $i 2}
    }

    method {submodule detail} {{DIR ""}} {
        set DIR [$self DIR $DIR]
        set out [exec git -C $DIR submodule status 2>@ stderr]
        set res []
        foreach line [split $out \n] {
            if {[regexp {^(.)(.{40}) (\S+)(?: \((.*)\))?$} $line -> state hash dir rev]} {
                lappend res [list [if {$rev eq "(null)"} {
                    list null
                } elseif {$state ne " "} {
                    set state
                }] $hash $dir]
            }
        }
        set res
    }

    method DIR {{DIR ""}} {
        if {$DIR ne ""} {
            set DIR
        } elseif {$options(-dir) ne ""} {
            set options(-dir)
        } else {
            return .
        }
    }

    method cmd-usage args {
        return "\
Usage: [file tail [info script]] \[--option=value\] METHOD ARGS...
Available methods:
[join [lsort [lmap i [$self info methods] {
  if {$i in {cget configure configurelist destroy}} continue
  if {[regexp ^cmd-(.*) $i -> rest]} {
    set rest
  } else {
    set i
  }
}]] \n]"
    }
}

snit::widget git-remote-editor::gui {

    component myTarget
    delegate method * to myTarget

    component myText
    constructor args {
        install myTarget using from args -target
        install myText using text $win.text
        pack $myText -fill both -expand yes

        after idle [list $self Reload]
    }

    method Reload {} {
        $myText delete 1.0 end
        foreach item [$myTarget url-list] {
            lassign $item dir remote
            $myText insert end $dir dir \t "" $remote remote \n
        }
    }
}

namespace eval git-remote-editor {
    proc dict-cut-default {dictVar name {default ""}} {
        upvar 1 $dictVar dict
        if {![dict exists $dict $name]} {
            return $default
        }
        set out [dict get $dict $name]
        dict unset dict $name
        return $out
    }

    proc parsePosixOpts {varName args} {
        set dict [dict-cut-default args dict [dict create]]
        set alias [dict-cut-default args alias [dict create]]
        if {$args ne ""} {
            error "Unknown args: $args"
        }
        
        upvar 1 $varName opts

        for {} {[llength $opts]
                && [regexp {^(?:-(\w)|--([\w\-]+)(?:(=)(.*))?)$} [lindex $opts 0] \
                        -> letter name eq value]} {set opts [lrange $opts 1 end]} {
            if {$letter ne ""} {
                if {![dict exists $alias $letter]} {
                    error "Unknown letter option: $letter"
                }
                set name [dict get $alias $letter]
                set value 1
            } elseif {$eq eq ""} {
                set value 1
            }
            dict set dict -$name $value
        }
        set dict
    }
}

if {![info level] && [info script] eq $::argv0} {
    apply {{type args} {
        set opts [${type}::parsePosixOpts args]

        set obj [$type create editor {*}$opts]

        set args [lassign $args cmd]

        if {$cmd eq ""} {
            puts stderr [$obj cmd-usage]
            exit 1
        }

        if {[$obj info methods cmd-$cmd] ne ""} {
            $obj cmd-$cmd {*}$args
        } elseif {[$obj info methods $cmd] ne ""
                  || [$obj info methods [list $cmd *]] ne ""} {
            puts [$obj $cmd {*}$args]
        } else {
            puts stderr "No such method: $cmd"
            puts stderr [$obj cmd-usage]
            exit 1
        }
    }} git-remote-editor {*}$::argv
}
