#!/usr/bin/env wish
# -*- coding: utf-8 -*-

package require snit
package require widget::scrolledwindow

snit::widget pointerevents {
    option -synclient synclient

    component myListener
    component myPane
    component myCanv -public canvas
    variable mySynConfigs {}
    variable myCurParams -array {}

    option -param SingleTapTimeout
    option -filter Tap
    option -value ""

    constructor args {
	$self build toplevel
	$self configurelist $args
	after 500 [list after idle [list $self Reload]]
    }
    method {build toplevel} {} {
	$self build menu

	set vbox [panedwindow $win.vbox -orient vertical]

	$self build configbar $vbox

	install myPane using panedwindow $vbox.hbox -orient horizontal
	$vbox add $myPane

	
	$myPane add [set sw [widget::scrolledwindow $myPane.sw[incr i]]]
	install myListener using text $sw.listener -width 25
	$sw setwidget $myListener

	$myPane add [set sw [widget::scrolledwindow $myPane.sw[incr i]]]
	install myCanv using canvas [set w $myPane.sw[incr i]]
	$sw setwidget $w

	$self bind canvas

	# pack $myPane -fill both -expand yes

	pack $vbox -fill both -expand yes
    }
    method {build menu} {} {
	[winfo toplevel $win] configure -menu [menu [set m $win.menu]]
	wm protocol [winfo toplevel $win] WM_DELETE_WINDOW [list $self Quit]

	$m add cascade -label File -menu [menu $m.file]
	$m.file add command -label Console -command [list $self console]
	$m.file add command -label Quit -command [list $self Quit]
    }

    method {build configbar} {vbox} {
	$vbox add [set lf [ttk::labelframe $vbox.control \
			       -text "Synaptics Settings"]]
	
	pack [ttk::combobox $lf.w[incr i] \
		  -textvariable [myvar options(-filter)] \
		  -values [list $options(-filter) *]] -side left -expand no
	trace add variable [myvar options(-filter)] write \
	    [list apply [list {self args} {$self Reload}] $self]

	pack [ttk::combobox [set w $lf.w[incr i]]\
		  -state readonly \
		  -textvariable [myvar options(-param)]] -side left
	trace add variable [myvar options(-param)] write\
	    [list apply [list {self args} {$self Reload}] $self]
	trace add variable [myvar mySynConfigs] write \
	    [list apply [list {self w vn args} {
		$w configure -values [set $vn]
		if {[set found [lsearch [set $vn] [$self cget -param]]] >= 0} {
		    if {[$w current] != $found} {
			$w current $found
		    }
		} else {
		    $w current 0
		}
	    }] $self $w [myvar mySynConfigs]]

	pack [ttk::spinbox [set w $lf.w[incr i]] \
		  -textvariable [myvar options(-value)] \
		  -to 10000 -increment 10 \
		  -command [list $self Change]
		 ] -side left
	bind $w <Return> [list $self Change]
	bind $w <Enter> [list $self Change]
    }

    method {bind canvas} {} {
	bind $myCanv <ButtonPress-1> [list $self Single Press 1]
	bind $myCanv <ButtonRelease-1> [list $self Single Release 1]
	bind $myCanv <B1-Motion> [list $self Single Motion 1]
	bind $myCanv <Double-ButtonPress-1> [list $self Double Press 1]
	bind $myCanv <Double-ButtonRelease-1> [list $self Double Release 1]
	bind $myCanv <Double-B1-Motion> [list $self Double Motion 1]
    }

    method Single args { $self log Single $args }
    method Double args { $self log Double $args }
    method log args {
	$myListener see end
	$myListener insert end $args\n
    }

    method Change {} {
	if {$myCurParams($options(-param)) eq $options(-value)} return
	set kv $options(-param)=$options(-value)
	$self log changing $kv
	exec $options(-synclient) $kv
	set myCurParams($options(-param)) $options(-value)
    }

    method Reload {} {
	# puts "reloading...(from [info frame 2])"
	set mySynConfigs [$self param list]
	if {$options(-param) ne ""} {
	    # XXX: This will call Change
	    set options(-value) $myCurParams($options(-param))
	}
    }

    method {param list} {} {
	set list {}
	array unset myCurParams
	if {$options(-filter) ne ""} {
	    set pat $options(-filter)
	    if {![regexp {\*} $pat]} {
		set pat *$pat*
	    }
	}
	foreach line [split [exec $options(-synclient)] \n] {
	    if {![regexp {^\s+(\w+)\s+=\s+(\d+)} $line -> key val]} continue
	    set myCurParams($key) $val
	    if {[info exists pat] && ![string match $pat $key]} continue
	    lappend list $key
	}
	set list
    }

    method Quit {} {
	exit
    }

    method console {} {
	package require tclreadline
	tclreadline::readline eofchar [list $self Quit]
	after idle tclreadline::Loop
    }
}

if {![info level] && [info script] eq $::argv0} {
    wm geometry . 1000x900
    pack [pointerevents .win {*}$::argv] -fill both -expand yes
    # catch {after 500 {after idle {.win console}}}
}
