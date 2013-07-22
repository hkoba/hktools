#!/usr/bin/env wish8.5
# -*- mode: tcl; coding: utf-8 -*-

# Usage: timeseries-plot.tcl -file data.tsv
#
# First row must be a header.
# First column must be a date/time. default format is %Y-%m-%d %H:%M:%S
# Other columns can be any numeric data.

# ToDo:
#  - statusbar (total # of data points, ...)
#  - preset of zoom
#  - progressbar for loading
#  - marker
#  - save setting and anotation of data
#  - postscript output => pdf
#


package require BLT
package require snit

if {![llength [info commands blt::graph]]} {
    error "blt::graph is required!"
}

snit::widget timeseries {
    option -file
    option -list

    option -start
    option -center

    option -timeparse "%Y-%m-%d %H:%M:%S"
    option -timeinput "%Y-%m-%d %H:%M:%S"
    option -timelabel "%Y-%m-%d\n(%a)\n%H:%M:%S"

    # 
    # option -orient horizontal; # or vertical

    component myGraph -public graph

    option -closecommand ::exit

    variable myAppName
    constructor args {
	$type ensure-load-bltgraph

	install myAppName using wm title [winfo toplevel $win]

	$self build menu

	set i 0
	$self build navbar [$self packed {
	    -fill x -expand no -side top
	} frame $win.f[incr i]]

	$self build graph [$self packed {
	    -fill both -expand yes
	} frame $win.f[incr i]]

	$self build statusbar [$self packed {
	    -fill x -expand no
	} frame $win.f[incr i]]

	$self configurelist $args

	if {[set cmd $options(-closecommand)] ne ""} {
	    wm protocol [winfo toplevel $win] WM_DELETE_WINDOW $cmd
	}
    }

    method {build menu} {} {
	[winfo toplevel $win] configure -menu [set m [menu $win.menu]]
	$m add cascade -label File -menu [menu $m.file]
	$m.file add command -label Open -command [list $self Open]
	$m.file add command -label Quit -command ::exit
    }

    variable myCurDate
    variable myRangeMins ""
    method {build navbar} frm {
	set i 0
	lappend wl [label $frm.f[incr i] -text Goto]\
	    [ttk::entry $frm.f[incr i] -textvariable [myvar options(-center)]]
	bind [lindex $wl end] <Return> [list $self Goto]

	lappend wl [label $frm.f[incr i] -text "Range (mins)"]\
	    [ttk::entry $frm.f[incr i] -textvariable [myvar myRangeMins]]
	bind [lindex $wl end] <Return> [list $self Goto]

	lappend wl [label $frm.f[incr i] -text Current]\
	    [ttk::entry $frm.f[incr i] -textvariable [myvar myCurDate]]

	pack {*}$wl -side left -fill x -expand no
    }

    method Goto {} {
	$self time goto [clock scan $options(-center)]
    }

    method {build graph} {frm} {
	install myGraph using blt::graph $frm.gra \
	    -takefocus 1

	# グリッドの表示形式
	# $myGraph grid configure -dashes {2 2} -minor no

	# Y 軸は値
	set sy [scrollbar $frm.gra_y -command [list $myGraph axis view y]\
		    -orient vertical -relief flat]
	$myGraph axis configure y -scrollcommand [list $sy set] \
	    -subdivisions 0 -scrollincrement 1\
	    -command [list $self tick format y]

	# X 軸は時間軸
	# timeseries が相手なので、tick を荒くしないとすぐ上限に。
	set sx [scrollbar $frm.gra_x -command [list $myGraph axis view x]\
		    -orient horizontal -relief flat]
	$myGraph axis configure x -scrollcommand [list $sx set] \
	    -stepsize [expr {3600*24}] \
	    -scrollincrement 1 \
	    -command [list $self tick format x]
	# XXX: zoom に合わせて -stepsize/-subdivisions/ format... を調整したい

	bind $myGraph <Enter> [list focus $myGraph]

	bind $myGraph <Left> [list $myGraph axis view x scroll -1 units]
	bind $myGraph <Shift-Left> [list $myGraph axis view x scroll -1 pages]
	bind $myGraph <Right> [list $myGraph axis view x scroll 1 units]
	bind $myGraph <Shift-Right> [list $myGraph axis view x scroll 1 pages]

	# Zoom 機能を On に。
	blt::ZoomStack $myGraph
	::Blt_ActiveLegend $myGraph

	$myGraph crosshairs on
	bind $myGraph <Motion> [list $self Motion %x %y]

	gridrow r $myGraph {-sticky news} $sy {-sticky ns}
	grid rowconfigure $frm $r -weight 5
	grid columnconfigure $frm 0 -weight 5
	gridrow r $sx {-sticky ew}
    }

    method {build statusbar} frm {
    }

    #========================================
    method Open {{fn ""}} {
	if {$fn eq ""} {
	    set fn [tk_getOpenFile \
			-title "Please choose input file(tab separated text)"]
	    if {$fn eq ""} {
		return
	    }
	}
	$self plot file $fn
    }

    #========================================

    method {tick format y} {w value} {
	return $value
    }

    method {tick format x} {w value} {
	clock format [expr {int($value)}] -format $options(-timelabel)
    }

    method Motion {x y} {
	$myGraph crosshairs configure -position @$x,$y
	set sec [expr {int([$myGraph axis invtransform x $x])}]
	set myCurDate [clock format $sec -format $options(-timeinput)]
    }

    #========================================

    option -colorlist [list #7788ff #44cc00 #ffaa33 #ff4466 \
			   \#8822ff #00ddcc #00ddcc #55ffbb ]

    option -headerlist
    option -separator \t
    variable myHeaderList
    variable myVectList
    variable myVectDict -array {}
    method {set header} hlist {
	set myHeaderList $hlist
	foreach cmd [info commands $self.vec*] {
	    rename $cmd ""
	}
	set myVectList {}

	set c 0
	foreach title $myHeaderList {
	    lappend myVectList [set myVectDict($title) \
				    [blt::vector create $self.vec[incr c]]]
	    if {[llength $myVectList] >= 2} {
		set fill {}
		if {[llength $myVectList] == 2} {
		    # set fill [list -areapattern solid -areaforeground grey70]
		}
		$myGraph element create $title \
		    -xdata [lindex $myVectList 0] \
		    -ydata [lindex $myVectList end] \
		    -symbol none -pixels 0\
		    -color [lindex $options(-colorlist) [expr {$c - 2}]]\
		    {*}$fill
	    }
	}
    }

    method {time allrange} {} {
	lassign $myVectList tvec
	if {![$tvec length]} return
	list [$tvec index 0] [$tvec index end]
    }

    method column {name args} {
	set vn myVectDict($name)
	if {![info exists $vn]} {
	    error "No such column! $name"
	}
	set vec [set $vn]
	if {[llength $args]} {
	    $vec {*}$args
	} else {
	    set vec
	}
    }

    method {time vector} args {
	set tvec [lindex $myVectList 0]
	if {[llength $args]} {
	    $tvec {*}$args
	} else {
	    set tvec
	}
    }

    method {time goto} goto {
	lassign $myVectList tvec

	if {$myRangeMins eq ""} {
	    set start [$myGraph axis cget x -min]
	    set end [$myGraph axis cget x -max]
	    if {$start eq "" || $end eq ""} return
	    set halfwidth [expr {($end - $start)/2}]
	} else {
	    set halfwidth [expr {($myRangeMins * 60)/2}]
	}
	set min [expr {$goto - $halfwidth}]
	set max [expr {$goto + $halfwidth}]
	$myGraph axis configure x -min $min -max $max
	set options(-center) [clock format $goto \
				  -format $options(-timeinput)]
    }

    method {add line} {cols {start ""}} {
	set sec [clock scan [lindex $cols 0] -format $options(-timeparse)]
	if {$start ne "" && $sec < $start} {
	    return 0
	}
	
	set othvecs [lassign $myVectList tvec]
	
	if {[$tvec length]} {
	    set s [expr {int([$tvec index end] + 1)}]
	    for {} {$s < $sec} {incr s} {
		vector-add-time-values $tvec $s $othvecs {} 0
	    }
	}

	vector-add-time-values $tvec $sec $othvecs $cols 0

	set sec
    }

    proc vector-add-time-values {tvec sec othvecs cols default} {
	$tvec append $sec
	set c 0
	foreach v $othvecs {
	    $v append [lindex-default $cols [incr c] $default]
	}
    }

    method {plot file} {fn} {
	set fh [open $fn]
	wm title [winfo toplevel $win] "[file tail $fn] - $myAppName"
	$self plot chan $fh
	close $fh
    }

    method {plot chan} fh {
	set now [clock seconds]
	$self set header [split [gets $fh] $options(-separator)]
	if {$options(-start) ne ""} {
	    set startSec [clock scan $options(-start)]
	} else {
	    set startSec ""
	}
	set i 0
	set limited 0
	set myRangeMins ""
	while {[gets $fh line] >= 0} {
	    set cols [split $line $options(-separator)]
    
	    if {![set sec [$self add line $cols $startSec]]} continue

	    if {![info exists firstSec]} {
		set firstSec $sec
	    } elseif {!$limited
		      && ($sec - $firstSec) > (3600 * 4)} {
		puts "now narrowing mode"
		$myGraph axis configure x -min $firstSec -max $sec
		set myRangeMins [expr {($sec - $firstSec)/60}]
		set limited 1
	    }

	    if {$i % 10000 == 0} {
		puts i=$i,sec=$sec,[clock format $sec -format $options(-timeinput)],cols=[lrange $cols 1 end]\r
		$self time goto $sec
		update
	    }

	    incr i
	}
	set elapsed [expr {[clock seconds] - $now}]
	set points [$self time vector length]
	puts "DONE(elapsed=${elapsed}s, total datapoints=$points)"
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

    method packed {packOpts kind path args} {
	pack [$kind $path {*}$args] {*}$packOpts
	set path
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

    proc ymd datetime {
	clock format [clock scan $datetime] -format %Y-%m-%d
    }

    proc lindex-default {list index default} {
	if {$index < [llength $list]} {
	    lindex $list $index
	} else {
	    set default
	}
    }
}

if {![info level] && [info script] eq $::argv0} {
    pack [timeseries .win {*}$::argv] -fill both -expand yes
    if {[set fn [.win cget -file]] ne ""} {
	.win plot file $fn
    }
}
