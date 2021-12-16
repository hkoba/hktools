#!/usr/bin/tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

package require Tcl 8.5
package require snit
package require struct::list

snit::type git-remote-editor {
    option -dir ""
    option -remote origin
    option -src-prefix ""
    option -src-suffix .git
    option -dest-prefix ""
    option -dest-suffix .git

    option -map ""
    option -map-file ""

    variable myGitHasChdirOption ""

    constructor args {
        $self configurelist $args
        set myGitHasChdirOption [expr {[package vcompare [lindex [exec git --version] end] 1.8.4.1] >= 0}]
    }

    onconfigure -map-file fileName {
        set fh [open $fileName]
        while {[gets $fh line] >= 0} {
            lassign [split $line \t] src dest
            dict set options(-map) $src $dest
        }
        close $fh
    }

    method GitHasChdirOption {} {
        set myGitHasChdirOption
    }

    method gui args {
        set win [from args -widget .win]
        package require Tk
        ${type}::gui $win -target $self {*}$args
        pack $win -fill both -expand yes
    }

    method cmd-info args {
        set result [$self info {*}$args]
        if {[lindex $args 0] eq "methods"} {
            set result [struct::list mapfor i $result {
                if {[regexp ^cmd- $i]} continue
                set i
            }]
        }
        puts [join $result \n]
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

    method cmd-full-rewrite-map {} {
        set dict [$self full-rewrite-map]
        foreach cur [dict keys $dict] {
            puts $cur\t[dict get $dict $cur]
        }
    }

    method full-rewrite-map {} {
        set dict [dict create]
        foreach cur [dict keys $options(-map)] {
            dict set dict $options(-src-prefix)$cur \
                $options(-dest-prefix)[$self rewrite-with \
                                           [dict get $options(-map) $cur] $cur]
        }
        set dict
    }

    method new-url remote {
        set remote [$self remote $remote]
        set remote [$self trim-url $remote]
        if {![dict exists $options(-map) $remote]} return
        set stem [$self rewrite-with \
                      [dict get $options(-map) $remote] $remote]
        return $options(-dest-prefix)$stem$options(-dest-suffix)
    }

    method cmd-map args {
        puts [join [$self map {*}$args] \n]
    }
    method map args {
        struct::list mapfor i $args {
            $self rewrite-with \
                [dict get $options(-map) $i] $i
        }
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
        $self chdir-git $DIR config remote.$remote.url
    }

    method list {{DIR ""}} {
        set DIR [$self DIR $DIR]
        set result []
        foreach item [$self submodule detail $DIR] {
            lassign $item status commit sub
            lappend result $sub
            if {$status eq "-"} continue
            set subList [$self list $DIR/$sub]
            lappend result {*}[struct::list mapfor i $subList {
                value $DIR/$sub/$i
            }]
        }
        set result
    }

    method {submodule list} {{DIR ""}} {
        struct::list mapfor i [$self submodule detail $DIR] {lindex $i 2}
    }

    method {submodule detail} {{DIR ""}} {
        set DIR [$self DIR $DIR]
        set out [$self submodule status-in $DIR]
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

    method {submodule status-in} {DIR} {
        $self chdir-git $DIR submodule status 2>@ stderr
    }

    method {chdir-git} {DIR args} {
        if {$myGitHasChdirOption} {
            exec git -C $DIR {*}$args
        } else {
            set cwd [pwd]
            cd $DIR
            set result [exec git {*}$args]
            cd $cwd
            set result
        }
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
[join [lsort [struct::list mapfor i [$self info methods] {
  if {$i in {cget configure configurelist destroy}} continue
  if {[regexp ^cmd-(.*) $i -> rest]} {
    set rest
  } else {
    set i
  }
}]] \n]"
    }

    proc value value {
        set value
    }
}

snit::widget git-remote-editor::gui {

    component myTarget
    delegate method * to myTarget

    component myText

    option -dry-run 0
    option -undo 0
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
        pack [ttk::button $bf.b[incr i] -text Undo -command [list $self Replace undo yes]] -side left

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

    method Replace {args} {
        set undo [dict-default $args undo no]
        set remote [$myTarget remote]
        foreach item [$self current-list] {
            lassign $item dir current new
            if {$new eq ""} continue
            set cmd [if {$undo} {
                list git -C $dir config remote.$remote.url $current
            } else {
                list git -C $dir config remote.$remote.url $new
            }]
            puts $cmd
            if {$options(-dry-run)} continue
            if {[$myTarget GitHasChdirOption]} {
                exec {*}$cmd >@ stdout 2>@ stderr
            } else {
                $myTarget chdir-git $dir {*}[lrange $cmd 3 end]
            }
        }
    }

    method current-list {} {
        struct::list mapfor i [split [$myText get header.last end-1c] \n] {
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
            [struct::list mapfor i [dict values $measure] {
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
