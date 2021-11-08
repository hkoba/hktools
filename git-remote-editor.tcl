#!/usr/bin/tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

package require Tcl 8.6
package require snit

snit::type git-remote-editor {
    option -dir ""
    option -remote origin
    option -src-prefix ""
    option -src-suffix .git
    option -dest-prefix ""
    option -dest-suffix .git

    option -map ""
    option -map-file ""
    onconfigure -map-file fileName {
        set fh [open $fileName]
        while {[gets $fh line] >= 0} {
            lassign [split $line \t] src dest
            dict set options(-map) $src $dest
        }
        close $fh
    }

    method gui args {
        set win [from args -widget .win]
        package require Tk
        ${type}::gui $win -target $self {*}$args
        pack $win -fill both -expand yes
    }

    method rewrite-list {{remote origin} {DIR ""}} {
        set remote [$self remote $remote]
        set result []
        foreach item [$self url-list $remote $DIR] {
            lassign $item dir remote
            set new [$self new-url $remote]
            if {$new eq ""} continue
            lappend result [list $dir $new]
        }
        set result
    }

    method new-url remote {
        set remote [$self remote $remote]
        set remote [$self trim-url $remote]
        if {![dict exists $options(-map) $remote]} return
        set stem [$self rewrite-with \
                      [dict get $options(-map) $remote] $remote]
        return $options(-dest-prefix)$stem$options(-dest-suffix)
    }

    method rewrite-with {spec original} {
        if {[regexp {/$} $spec]} {
            return $spec[file tail $original]
        } else {
            return $spec
        }
    }

    method trim-url url {
        if {$options(-src-prefix) ne ""} {
            set len [string length $options(-src-prefix)]
            if {[string equal -length $len $options(-src-prefix) $url]} {
                set url [string range $url $len end]
            }
        }
        if {$options(-src-suffix) ne ""} {
            set pos [expr {[string length $url]
                           - [string length $options(-src-suffix)]}]
            if {[string range $url $pos end] eq $options(-src-suffix)} {
                set url [string range $url 0 [expr {$pos - 1}]]
            }
        }
        set url
    }

    method cmd-url-list {{remote origin} {DIR ""}} {
        set remote [$self remote $remote]
        foreach item [$self url-list $remote $DIR] {
            puts [join $item \t]
        }
    }
    method url-list {{remote origin} {DIR ""}} {
        set remote [$self remote $remote]
        set DIR [$self DIR $DIR]
        set result [list [list $DIR [$self git remote-url $remote $DIR]]]
        foreach sub [$self list $DIR] {
            lappend result [list $sub [$self git remote-url $remote $sub]]
        }
        set result
    }

    method {git remote-url} {{remote origin} {DIR ""}} {
        set remote [$self remote $remote]
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

    method remote {{remote ""}} {
        if {$remote ne ""} {
            set remote
        } elseif {$options(-remote) ne ""} {
            set options(-remote)
        } else {
            return origin
        }
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

    method myvar {varName} {
        myvar $varName
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

    option -dry-run 0
    constructor args {
        install myTarget using from args -target

        $self configurelist $args

        # buttons
        set bf [ttk::frame $win.bf]
        pack $bf -fill x -expand no

        pack [ttk::button $bf.b[incr i] -text Replace -command [list $self Replace]] -side left
        pack [ttk::checkbutton $bf.b[incr i] -text "dry run" \
                  -onvalue 1 -offvalue 0 \
                  -variable [myvar options(-dry-run)]] -side left

        # configs
        set cf [ttk::frame $win.cf]
        pack $cf -fill x -expand no

        pack [ttk::labelframe [set f $cf.w[incr i]] -text "remote"] -side left -padx 0
        pack [ttk::entry [set e $f.w] -textvariable [$myTarget myvar options(-remote)]]
        bind $e <Return> [list $self Reload]

        pack [ttk::labelframe [set f $cf.w[incr i]] -text "src-prefix"] -side left -padx 0
        pack [ttk::entry [set e $f.w[incr i]] -textvariable [$myTarget myvar options(-src-prefix)] -width 30]
        bind $e <Return> [list $self Reload]

        pack [ttk::labelframe [set f $cf.w[incr i]] -text "dest-prefix"] -side left -padx 0
        pack [ttk::entry [set e $f.w[incr i]] -textvariable [$myTarget myvar options(-dest-prefix)] -width 30]
        bind $e <Return> [list $self Reload]

        install myText using text $win.text -wrap none
        pack $myText -fill both -expand yes

        # XXX: idle だと toplevel の geometry が確定してない
        after 100 [list $self Reload]
    }

    method Replace {} {
        foreach item [$self current-list] {
            puts $item
            lassign $item dir current new
            set cmd [list git -C [$myTarget DIR]]
            if {$options(-dry-run)} {
                
            }
        }
    }

    method current-list {} {
        lmap i [split [$myText get header.last end-1c] \n] {
            split $i \t
        }
    }

    method Reload {} {
        $myText delete 1.0 end
        # XXX: writable
        set font [$myText cget -font]
        set measure []

        $myText tag configure header -borderwidth 2 -relief raised -background palegreen
        $myText insert end dir {header dir} \t header current {header current} \t header new {header new} \n header
        foreach item [$myTarget url-list] {
            lassign $item dir current
            set new [$myTarget new-url $current]
            $myText insert end $dir dir \t "" $current current \t "" $new new \n
            foreach vn {dir current new} {
                dict set measure $vn \
                    [max [font measure $font [set $vn]] \
                        [dict-default $measure $vn 0]]
            }
            # XXX: column width, tab width
        }
        set margin [font measure $font "  "]
        set accm 0
        $myText configure -tabs \
            [lmap i [dict values $measure] {
                set accm [expr {$accm + $i + $margin}]
            }]
        # XXX: readonly
        $self geometry autofit
    }

    method {geometry autofit} {} {
        set overflowWidth [window-overflow [$myText xview] [winfo width $myText]]
        set newGeometry [modify-geometry [wm geometry [winfo toplevel $win]] \
                 $overflowWidth "" "" ""]
        wm geometry [winfo toplevel $win] $newGeometry
    }

    proc modify-geometry {geometry widthDiff heightDiff xDiff yDiff} {
        lassign [split $geometry x+] \
            curWidth curHeight curX curY
        foreach curVar {curWidth curHeight curX curY} diffVar {widthDiff heightDiff xDiff yDiff} {
            if {[set $diffVar] ne ""} {
                set $curVar [expr {[set $curVar] + [set $diffVar]}]
            }
        }
        return ${curWidth}x${curHeight}+$curX+$curY
    }

    proc window-overflow {viewPair current} {
        lassign $viewPair begin end
        set ratio [expr {$end - $begin}]
        expr {int($current * ((1 - $ratio)/$ratio))}
    }

    proc max {l r} {
        expr {$l > $r ? $l : $r}
    }
    proc dict-default {dict key default} {
        if {[dict exists $dict $key]} {
            dict get $dict $key
        } else {
            set default
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

        set moreOpts [${type}::parsePosixOpts args]

        if {[$obj info methods cmd-$cmd] ne ""} {
            $obj cmd-$cmd {*}$moreOpts {*}$args
        } elseif {[$obj info methods $cmd] ne ""
                  || [$obj info methods [list $cmd *]] ne ""} {
            puts [$obj $cmd {*}$moreOpts {*}$args]
        } else {
            puts stderr "No such method: $cmd"
            puts stderr [$obj cmd-usage]
            exit 1
        }
    }} git-remote-editor {*}$::argv
}
