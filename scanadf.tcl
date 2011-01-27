#!/usr/bin/wish

package require snit
package require BWidget

# XXX: Focus management.
# XXX: Shift-Return

# XXX: gthum preview
# XXX: note saving.
# XXX: Cancel button

# XXX: -filefmt, -dirfmt combobox, pwd entry
# XXX: paper size selection/saving
# XXX: DPI
# XXX: tooltip

snit::widget scanadf {
    component myScannerList

    option -verbose 0
    option -debug no

    option -npages 60
    option -npages-choice {60 40 30 10 2 1}

    option -mode Gray

    option -dir ""
    option -dirfmt %Y%m%d-%H:%M
    option -filefmt p%03d.pnm

    component myMessage
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
    constructor args {
	$self setup menu

	lappend frames [set bf [labelframe $win.bf -text スキャン]]
	set o [list -width 5]
	set i 0
	gridrow r [label $bf.b[incr i] -text {Scanning Page}] \
	    {-sticky e} \
	    [frame [set f $bf.b[incr i]]] \
	    {-sticky w}
	install myPageHistFrm using set f
	pack [spinbox $f.spin {*}$o -textvariable [myvar options(-i)]\
		 -to 100000]\
	    [button $f.back -text << -command [list $self history back]]\
	    [button $f.forw -text >> -command [list $self history forw]]\
	    [button $f.cancel -text Cancel -command [list $self Cancel]]\
	    -side left
	$self history update

	gridrow r [spinbox [set UntilEnd $bf.b[incr i]] {*}$o \
		       -textvariable [myvar options(-end)] \
		       -to 100000 ] \
	    {-sticky e} \
	    [button $bf.b[incr i] -text このページまでスキャン \
		 -command [list $self Scan UntilEnd]]  \
	    {-sticky ew}
	foreach ev {Return KP_Enter} {
	    bind $UntilEnd <$ev> [list $self Scan UntilEnd]
	}
	bind $UntilEnd <1> [list $UntilEnd selection range 0 end]
	gridrow r [ttk::combobox $bf.b[incr i] {*}$o \
		  -textvariable [myvar options(-npages)] \
		       -values $options(-npages-choice)] \
	    {-sticky e} \
	    [button [set NPages $bf.b[incr i]] -text ページ分だけスキャン \
		 -command [list $self Scan NPages]] \
	    {-sticky ew}

	lappend frames [set f [labelframe $win.dir -text 保存ディレクトリ]]
	pack [entry $f.dir -textvariable [myvar curBook]] -fill x -expand yes \
	    -side left
	pack [button $f.new -text 次の本へ \
		  -command [list $self newbook]]

	# paned?
	lappend frames [set f [labelframe $win.notify -text コンソール]]
	pack [ScrolledWindow [set sw $f.cons]] -fill both -expand yes
	install myMessage using text $sw.t -height 6 -width 38 -wrap none
	$sw setwidget $myMessage
	$self setup message

	pack {*}$frames -side top -fill both -expand yes
	foreach w [list $win {*}$frames] {
	    foreach ev {Return KP_Enter Key-space Tab} {
		bind $w <$ev> [list focus $NPages]
	    }
	}
	bind $win <Enter> [list focus $win]
	
	$self configurelist $args

	if {$options(-dir) ne ""} {
	    cd $options(-dir)
	    set options(-dir) [pwd]
	} else {
	    set options(-dir) [pwd]
	}

	$self newbook

	if {$options(-debug)} {
	    update idletask
	    after idle [list $self console]
	}
    }

    method {setup menu} {} {
	[winfo toplevel $win] configure -menu [menu [set m $win.menu]]

	$m add cascade -label File -menu [menu $m.file]
	$m.file add command -label Quit -command exit

	$m add cascade -label Option -menu [menu $m.option]
	$m.option add radiobutton -label Gray -variable [myvar options(-mode)]
	$m.option add radiobutton -label Color -variable [myvar options(-mode)]

	$m add cascade -label Debug -menu [menu $m.debug]
	$m.debug add command -label Console -command [list $self console]
    }
    method console {} {
	package require tclreadline
	after idle tclreadline::Loop
    }
    method {setup message} {} {
	foreach {tag style} {
	    ok {-foreground blue}
	    done {-foreground green}
	    error {-background red}
	    warn {-background cyan}
	} {
	    $myMessage tag configure $tag {*}$style
	}
    }

    option -device fujitsu
    option -source "ADF Duplex"

    option -i 1
    option -end ""
    variable myPageHist [list]
    component myPageHistFrm
    variable myTask ""
    variable curBook ""
    method newbook {} {
	set options(-i) 1
	$self history clear
	set curBook [clock format [clock seconds] -format $options(-dirfmt)]
    }
    method {history clear} {} {
	set myPageHist ""
	$self history update
    }
    method {history add} {} {
	if {[set pos [$self history pos]] >= 0} {
	    set myPageHist [lreplace $myPageHist $pos end]
	}
	lappend myPageHist $options(-i)
    }
    method {history forw} {} {
	set pos [$self history pos]
	if {$pos < [llength $myPageHist]-1} { $self history goto $pos 1 }
    }
    method {history back} {} {
	set pos [$self history pos]
	if {[llength $myPageHist] && $pos < 0} {
	    lappend myPageHist $options(-i)
	    set options(-i) [lindex $myPageHist end-1]
	} elseif {$pos > 0} { $self history goto $pos -1 }
    }
    method {history goto} {base off} {
	set options(-i) [lindex $myPageHist [expr {$base + $off}]]
	$self history update
    }
    method {history list} {} {
	set myPageHist
    }
    method {history pos} {} {
	set pos [lsearch $myPageHist $options(-i)]
    }
    method {history update} {} {
	set state [if {![llength $myPageHist]} {
	    list back disabled forw disabled
	} elseif {[set pos [$self history pos]] == 0} {
	    list back disabled forw active
	} elseif {$pos < 0 || $pos >= [llength $myPageHist]-1} {
	    list back active forw disabled
	} else {
	    list back active forw active
	}]
	
	foreach {w state} [linsert $state end cancel disabled] {
	    $myPageHistFrm.$w configure -state $state
	}
    }
    method Cancel {{state ""}} {
	if {$state ne ""} {
	    $myPageHistFrm.cancel configure -state $state
	} elseif {$myTask ne ""} {
	    exec kill [pid $myTask]
	}
    }
    variable myExpectedPages ""
    method Scan {mode} {
	if {$myTask ne ""} return

	if {$curBook eq ""} {
	    $self newbook
	}
	if {![file exists $curBook]} {
	    file mkdir $curBook
	}
	set cmd [list scanadf \
		     --device $options(-device) \
		     --source $options(-source) \
		     {*}[$self opt resolution] \
		     --mode $options(-mode) \
		     {*}[$self opt paper] \
		     -o $curBook/$options(-filefmt) \
		     -s $options(-i) \
		]
	$self history add
	switch $mode {
	    NPages {
		set end [set options(-end) \
				    [expr {$options(-i) + $options(-npages)
					   - 1}]]
	    }
	    UntilEnd {
		set end $options(-end)
	    }
	    default {
		error "Invalid Scan mode($mode)!"
	    }
	}
	set myExpectedPages [expr {$end - $options(-i) + 1}]
	lappend cmd -e $end 2>@1
	$self dputs cmd=$cmd
	set myTask [open [list | {*}$cmd]]
	fileevent $myTask readable [list $self readable $myTask]
	$self Cancel active
    }

    method {opt resolution} {} {
	list --resolution 100 --y-resolution 100
    }
    method {opt paper} {} {
	list -x 130 -y 190 --page-width 130 --page-height 190
    }

    method Error line {
	after idle [list $self Finish]
	$self emit $line error
	error $line
    }
    method Finish {} {
	$self history update
	if {[catch {close $myTask} error]} {
	    $self emit $error\n error
	}
	set myTask ""; # assert {$myTask eq $chan}
    }
    method emit {msg {tag ""} args} {
	$myMessage insert end $msg $tag {*}$args
	if {[$myMessage get end-1c] ne "\n"} {
	    $myMessage insert end \n
	}
	$myMessage see end
    }
    method readable chan {
	set rc [catch {
	    if {[eof $chan]} {
		$self emit <EOF> warn
		$self Finish
	    } else {
		gets $chan line
		if {[regexp {^scanadf: (.*)} $line -> msg]} {
		    $self emit $line\n warn
		} elseif {[regexp {^Scanned document (.*)} $line -> fpath]} {
		    scan [file tail $fpath] $options(-filefmt) num
		    set options(-i) [expr {$num + 1}]
		    $self emit $line\n ok
		} elseif {[regexp {^Scanned (\d+) pages} $line -> pages]} {
		    if {$pages == $myExpectedPages} {
			$self emit $line\n done
		    } else {
			$self emit $line\n error
		    }
		    $self Finish
		} elseif {[regexp jammed $line]} {
		    $self Error $line\n
		} else {
		    $self emit $line\n
		}
	    }
	} error]
	if {$rc} {
	    if {[info exists line]} {
		after idle [list $self emit $line\n warn]
	    }
	    after idle [list $self emit $error\n error]
	    after idle [list error $error]
	}
    }
    method myvar vn {
	myvar $vn
    }

    method dputs args {
	$myMessage insert end $args\n
	if {! $options(-verbose)} return
	puts stderr $args
    }
}

if {[info level] == 0 && $::argv0 eq [info script]} {
    pack [scanadf .win {*}$::argv] -fill both -expand yes
}

# Local Variables: **
# coding: utf-8 **
# End: **
