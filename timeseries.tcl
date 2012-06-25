#!/usr/bin/env wish8.5
# -*- mode: tcl; coding: utf-8 -*-

package require BLT
package require snit

if {![llength [info commands blt::graph]]} {
    error "blt::graph is required!"
}

snit::widget timeseries {
    option -file
    option -list

    option -timeparse "%Y-%m-%d %H:%M:%S"
    option -timelabel "%Y-%m-%d\n(%a)\n%H:%M:%S"

    # 
    # option -orient horizontal; # or vertical

    component myGraph -public graph

    option -closecommand ::exit

    constructor args {
	$type ensure-load-bltgraph

	$self build menu

	$self build graph

	$self configurelist $args

	if {[set cmd $options(-closecommand)] ne ""} {
	    wm protocol [winfo toplevel $win] WM_DELETE_WINDOW $cmd
	}
    }

    method {build menu} {} {
	[winfo toplevel $win] configure -menu [set m [menu $win.menu]]
	$m add cascade -label File -menu [menu $m.file]
	$m.file add command -label Quit -command ::exit
    }

    method {build graph} {} {
	install myGraph using blt::graph $win.gra

	# グリッドの表示形式
	$myGraph grid configure -dashes {2 2} -minor no


	# Y 軸は値
	set sy [scrollbar $win.gra_y -command [list $myGraph axis view y]\
		    -orient vertical -relief flat]
	$myGraph axis configure y -scrollcommand [list $sy set] \
	    -subdivisions 0 -scrollincrement 1\
	    -command [list $self tick format y]

	# X 軸は時間軸
	# timeseries が相手なので、tick を荒くしないとすぐ上限に。
	set sx [scrollbar $win.gra_x -command [list $myGraph axis view x]\
		    -orient horizontal -relief flat]
	$myGraph axis configure x -scrollcommand [list $sx set] \
	    -stepsize [expr {3600*24}] -subdivisions 60\
	    -scrollincrement 1 \
	    -command [list $self tick format x]

	# Zoom 機能を On に。
	blt::ZoomStack $myGraph

	gridrow r $myGraph {-sticky news} $sy {-sticky ns}
	grid rowconfigure $win $r -weight 5
	grid columnconfigure $win 0 -weight 5
	gridrow r $sx {-sticky ew}
    }

    method {tick format y} {w value} {
	return $value
    }

    method {tick format x} {w value} {
	clock format [expr {int($value)}] -format $options(-timelabel)
    }

    option -headerlist
    option -separator \t
    variable myHeaderList

    variable myVectList
    method plot {} {
	update

	set fh [open $options(-file)]
	set myHeaderList [split [gets $fh] $options(-separator)]
	if {[llength $myHeaderList] != 2} {
	    error "Too many columns! $myHeaderList"
	}

	set myVectList {}
	set c 0
	foreach title $myHeaderList {
	    lappend myVectList [blt::vector create $self.vec[incr c]]
	    if {[llength $myVectList] >= 2} {
		$myGraph element create $title \
		    -xdata [lindex $myVectList 0] \
		    -ydata [lindex $myVectList end] \
		    -pixels 2 \
		    
	    }
	}
	set i 0
	while {[gets $fh line] >= 0} {
	    set cols [split $line $options(-separator)]
	    set sec [clock scan [lindex $cols 0] -format $options(-timeparse)]

	    [lindex $myVectList 0] append $sec
	    for {
		set c 1
	    } {$c < max([llength $myVectList], [llength $cols])} {
		incr c
	    } {
		[lindex $myVectList $c] append [lindex $cols $c]
	    }
	    if {$i % 10000 == 0} {
		puts i=$i,sec=$sec,cols=[lrange $cols 1 end]\r
		update
	    }

	    if {$i > 30000} break

	    incr i
	}

	puts "DONE"

	close $fh
    }

    method xview args {
	$myGraph axis view x {*}$args
    }
    method yview args {
	$myGraph axis view y {*}$args
    }

    #========================================
    typemethod ensure-load-bltgraph {} {
	if {[llength [info procs blt::ZoomStack]]} return
	set dn [info library]/blt[package require BLT]
	if {![file isdirectory $dn]
	    || ![file readable [set fn $dn/graph.tcl]]
	} {
	    error "Can't find blt::ZoomStack"
	}
	uplevel #0 [list source $fn]
    }

    #========================================
    proc gridrow {rowVar widget gridOpts args} {
	upvar 1 $rowVar row
	if {![info exists row]} {
	    set row 0
	} else {
	    incr row
	}
	set widgetList {}
	set optList {}
	foreach {widget gridOpts} [linsert $args 0 $widget $gridOpts] {
	    lappend widgetList $widget
	    lappend optList $gridOpts
	}
	grid {*}$widgetList
	for {set col 0} {$col < [llength $optList]} {incr col} {
	    set widget [lindex $widgetList $col]
	    set gridOpts [lindex $optList $col]
	    if {[llength $gridOpts]} {
		grid configure $widget -row $row -column $col \
		    {*}$gridOpts
	    }
	}
    }
}

if {![info level] && [info script] eq $::argv0} {
    pack [timeseries .win {*}$::argv] -fill both -expand yes
    .win plot
}
