#!/usr/bin/wish

package require snit
package require BWidget

# XXX: gthumb preview
# XXX: note saving.

# XXX: pwd entry
# XXX: DPI
# XXX: tooltip

snit::widget scanadf {
    option -verbose 0
    option -debug no

    option -npages 60
    option -npages-choice {60 40 30 10 2 1}

    option -mode Gray

    option -chdir ""
    option -bookdirfmt %Y%m%d-%H:%M
    option -filefmt p%03d.pnm

    option -amazon http://www.amazon.co.jp/gp/product/

    option -preset body
    component myPresetSelector
    option -preset-dict [dict create \
			     body [list -i 1 -mode Gray -filefmt p%03d.pnm] \
			     heading \
			     [list -i 1 -end 1 -next body \
				  -mode Color -filefmt h%03d.pnm] \
			     centercolor \
			     [list -mode Color -filefmt p%03d.pnm]]

    # newbook で reset した後に、どんな設定に戻すか
    option -reset-to

    # その他
    option -isbn ""

    # このスキャンが終了した後に、preset 又は papersize を自動変更する
    option -next

    onconfigure -next next {
	if {$next eq ""} {
	    # NOP
	} elseif {[llength $next] >= 2} {
	    $self finish add [list $self configure {*}$next]
	} elseif {[dict exists [$self cget -preset-dict] $next]} {
	    $self finish add [list $self configure -preset $next]
	} elseif {[dict exists $cf_papersize $next]} {
	    $self finish add [list $self configure -papersize $next]
	} else {
	    error "Unknown -next: $next"
	}
    }

    option -papersize 13x19
    option -paper-width ""
    option -paper-height ""

    variable cf_papersize [lrange {
	13x19 {130 190}

	少年漫画表紙 {172 376 -preset heading -next 少年漫画}
	少年漫画 {110 172 -preset body -reset-to {-papersize 少年漫画表紙}}

	少女漫画表紙 {176 381 -preset heading -next 少女漫画}
	少女漫画 {110 176 -preset body -reset-to {-papersize 少女漫画表紙}}
    } 0 end]

    constructor args {
	$self setup menu

	set i 0
	#----------------------------------------
	lappend frames [set f [labelframe $win.f[incr i] -text 付加情報]]
	set r 0	
	gridrow r [label $f.w[incr i] -text ISBN(10or13)] \
	    {-sticky ne} \
	    [ttk::entry [set w $f.w[incr i]] \
		 -validatecommand [list $self isbn validate] \
		 -textvariable [myvar options(-isbn)]] \
	    {-sticky nw}
	bind $w <Return> [list $self isbn open]

	#----------------------------------------
	lappend frames [set bf [frame $win.bf[incr i]]]; # 、画質、用紙サイズ

	pack [set f [labelframe $bf.f[incr i] -text 色/DPI ]] -side left
	pack [ttk::radiobutton $f.w[incr i] -value Gray -text Gray \
		  -variable [myvar options(-mode)]] \
	    [ttk::radiobutton $f.w[incr i] -value Color -text Color\
		 -variable [myvar options(-mode)]] \
	    [ttk::combobox $f.w[incr i] -width 4\
		 -textvariable [myvar options(-resolution)] \
		 -values {100 300 600} ] \
	    -side top

	pack [set f [labelframe $bf.f[incr i] -text 紙サイズ(mm) ]] -side left
	set r 0
	gridrow r [ttk::combobox [set w $f.b[incr i]] \
		       -textvariable [myvar options(-papersize)] \
		       -width 20 \
		       -postcommand [list apply [list {self w type} {
			   $w configure -values \
			       [${type}::lmodulo [$self config get papersize] 2 0]
		       }] $self $w $type]] \
	    {} - {} - {} - {}
	trace add variable [myvar options(-papersize)] write \
	    [set task [list apply [list {self args} {
		set psz [$self cget -papersize]
		set dic [dict get [$self config get papersize] $psz]
		# puts dic=$dic
		set cf [lassign $dic x y]
		$self configure -paper-width $x -paper-height $y {*}$cf
	    }] $self]]
	after idle $task

	set o [list -width 5]
	gridrow r [label $f.s[incr i] -text W] \
	    {} \
	    [spinbox [set w1 $f.s[incr i]] {*}$o \
		       -textvariable [myvar options(-paper-width)] \
		       -to 1000] \
	    {} \
	    [label $f.s[incr i] -text H] \
	    {} \
	    [spinbox [set w2 $f.s[incr i]] {*}$o \
		       -textvariable [myvar options(-paper-height)] \
		       -to 1000] \
	    {}
	foreach w [list $w1 $w2] {
	    bind $w <Return> [list $self papersize remember]
	}

	#----------------------------------------
	lappend frames [set bf [labelframe $win.f[incr i] \
				    -text ページ番号とスキャン枚数]]
	set o [list -width 5]
	set r 0;
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

	#----------------------------------------
	lappend frames [set f [labelframe $win.f[incr i] -text 保存先]]
	set r 0
	gridrow r [label $f.w[incr i] -text この本のディレクトリ] \
	    {-sticky ne} \
	    [frame [set sf $f.w[incr i]]]\
	    {-sticky nw}
	pack [entry $sf.w[incr i] -textvariable [myvar curBook]] \
	    -side left
	
	if {[file executable /usr/bin/gthumb]} {
	    pack [button $sf.w[incr i] -image [Bitmap::get open] \
		      -command [list $self preview]] \
	}

	gridrow r [label $f.w[incr i] -text ファイル名の書式] \
	    {-sticky ne} \
	    [ttk::combobox $f.w[incr i] -textvariable [myvar options(-filefmt)]\
		 -values [list $options(-filefmt) h%003d.pnm]]\
	    {-sticky nw}

	gridrow r [button $f.w[incr i] -text 次の本へ(カウンタをリセット) \
		       -command [list $self newbook]] \
	    {} - {}
	
	#----------------------------------------
	lappend frames [set f [labelframe $win.f[incr i] -text その他]]
	set r 0
	gridrow r [label $f.w[incr i] -text プリセット値の選択] \
	    {-sticky ne} \
	    [ttk::combobox [set myPresetSelector $f.preset] \
		 -state readonly \
		 -textvariable [myvar options(-preset)] \
		 -postcommand [list apply [list {self w} {
		     set ls {}
		     foreach {k v} [$self cget -preset-dict] {
			 lappend ls $k
		     }
		     $w configure -values $ls
		 }] $self $myPresetSelector] \
		]\
	    {-sticky nw}
	trace add variable [myvar options(-preset)] write \
	    [list apply [list {self args} {
		$self configure {*}[dict get [$self cget -preset-dict] \
					[$self cget -preset]]
	    }] $self]

	#----------------------------------------
	# paned?
	set f [labelframe $win.notify -text コンソール]
	pack [ScrolledWindow [set sw $f.cons]] -fill both -expand yes
	install myMessage using text $sw.t -height 6 -width 38 -wrap none
	$sw setwidget $myMessage
	$self setup message

	#========================================
	pack {*}$frames -side top -fill both -expand no
	pack $f -side top -fill both -expand yes
	foreach w [list $win {*}$frames $f] {
	    foreach ev {Return KP_Enter Key-space Tab} {
		bind $w <$ev> [list focus $NPages]
	    }
	}
	bind $win <Enter> [list focus $win]
	
	$self configurelist $args

	if {$options(-chdir) ne ""} {
	    cd $options(-chdir)
	    set options(-chdir) [pwd]
	} else {
	    set options(-chdir) [pwd]
	}

	after idle [list $self config load]

	$self newbook

	if {$options(-debug)} {
	    update idletask
	    after idle [list $self console]
	}
    }

    variable myDialogResult ""
    method {papersize remember} {} {
	set okcancel [list Add Cancel]
	set msg この用紙サイズに名前を付けてください
	set diag $win.diag
	if {[winfo exists $diag]} {
	    destroy $diag
	}
	Dialog $diag -cancel [lsearch $okcancel Cancel] \
	    -title $msg
	append msg "\nWidth $options(-paper-width)mm"
	append msg "\nHeight $options(-paper-height)mm"
	set f [$diag getframe]
	set r 0; set i 0
	gridrow r [message $f.msg -text $msg] {} - {}
	gridrow r [label $f.w[incr i] -text 用紙名] \
	    {} \
	    [entry $f.w[incr i] -textvariable [myvar myDialogResult]] \
	    {}
	
	foreach i $okcancel {
	    $diag add -text $i
	}
	set ans [$diag draw [lsearch $okcancel Add]]
	if {[lindex $okcancel $ans] eq "Cancel"} return
	if {$myDialogResult eq ""} return
	$self config lappend papersize $myDialogResult \
	    [list $options(-paper-width) $options(-paper-height)]
	$self configure -papersize $myDialogResult
    }

    ### Var Naming Convention for config load/save:
    ## variable named cf_$name, both of scalar and array.

    option -config -default "" -configuremethod {config load}
    variable myConfigModified 0
    method {config modified} args {
	if {[llength $args]} {
	    set myConfigModified [lindex $args 0]
	} else {
	    set myConfigModified
	}
    }
    method {config load} args {
	if {[llength $args] == 2} {
	    lassign $args opt fn
	    set options($opt) $fn
	} elseif {$options(-config) ne ""} {
	    set fn $options(-config)
	} elseif {![file exists [set fn [$self config default-file]]]} {
	    return
	}
	$self config read [read_file $fn]
    }
    method {config get} name { set cf_$name }
    method {config lappend} {name args} {
	lappend cf_$name {*}$args
	$self config modified 1
    }
    method {config read} data {
	foreach {cf value} $data {
	    set vn cf_$cf
	    if {[array exists $vn]} {
		array unset $vn
		array set $vn $value
	    } elseif {[info exists $vn]} {
		set $vn $value
	    } else {
		error "Unknown config item! $cf"
	    }
	}
	$self config modified 0
    }
    method {config varlist} {{invert ""}} {
	set varlist {}
	foreach varName [lsort [info vars ${selfns}::*]] {
	    set cfName [string range $varName [string length ${selfns}::] end]
	    if {![regsub ^cf_ $cfName {} cfName]} continue
	    if {$invert eq ""} {
		lappend varlist $varName $cfName
	    } else {
		lappend varlist $cfName $varName
	    }
	}
	set varlist
    }
    method {config dump} {} {
	set dump ""
	foreach {varName cfName} [$self config varlist] {
	    if {[array exists $varName]} {
		append dump $cfName " \{\n"
		foreach key [lsort -dictionary [array names $varName]] {
		    append dump "\t[list $key]"\
			" [list [set [set varName]($key)]]\n"
		}
		append dump "\}\n"
	    } elseif {[set len [llength [set $varName]]]
		      && $len % 2 == 0} {
		append dump $cfName " \{\n"
		foreach {key val} [set $varName] {
		    append dump "\t[list $key] [list $val]\n"
		}
		append dump "\}\n"
	    } else {
		append dump $cfName " [list [set $varName]]\n"
	    }
	}
	set dump
    }
    method {config save} {} {
	if {[set fn $options(-config)] eq ""} {
	    set fn [$self config default-file]
	}
	write_file $fn [$self config dump]
	$self config modified 0
    }
    method {config default-file} {} {
	if {[info exists ::env(HOME)]} {
	    return [file join $::env(HOME) \
			.[file tail [file rootname $::argv0]].cfg]
	} else {
	    return [file rootname [file normalize $::argv0]].cfg
	}
    }

    method Quit {} {
	if {[tk_messageBox -message "Really quit now?" -type okcancel]
	    ne "ok"} return
	if {[$self config modified]} {
	    $self config save
	}
	exit
    }

    method {setup menu} {} {
	[winfo toplevel $win] configure -menu [menu [set m $win.menu]]
	wm protocol [winfo toplevel $win] WM_DELETE_WINDOW [list $self Quit]

	$m add cascade -label File -menu [menu $m.file]
	$m.file add command -label "Save Config" \
	    -command [list $self config save]
	$m.file add separator
	$m.file add command -label Quit -command [list $self Quit]

	$m add cascade -label Option -menu [menu $m.option]
	$m.option add radiobutton -label Gray -variable [myvar options(-mode)]
	$m.option add radiobutton -label Color -variable [myvar options(-mode)]

	$m add cascade -label Debug -menu [menu $m.debug]
	$m.debug add command -label Console -command [list $self console]
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

    #========================================
    option -device fujitsu
    option -source "ADF Duplex"

    option -i 1
    option -end ""
    variable myLastScanResult ""
    variable myExpectedPages ""
    variable myTask ""
    variable curBook ""
    method newbook {} {
	set options(-i) 1
	set options(-isbn) ""
	$self history clear
	set curBook [clock format [clock seconds] -format $options(-bookdirfmt)]
	$self emit newBook=$curBook ok
	if {$options(-reset-to) ne ""} {
	    $self configure {*}$options(-reset-to)
	}
	set curBook
    }
    method Scan {mode} {
	if {$myTask ne ""} return

	if {$curBook eq ""} {
	    $self newbook
	}
	if {![file exists $curBook]} {
	    file mkdir $curBook
	}
	set isbn $curBook/isbn.txt
	if {$options(-isbn) ne ""
	    && ![file exists $isbn]} {
	    write_file $isbn "$options(-isbn)\n"
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
    method Cancel {{state ""}} {
	if {$state ne ""} {
	    $myPageHistFrm.cancel configure -state $state
	} elseif {$myTask ne ""} {
	    exec kill [pid $myTask]
	}
    }

    method Error line {
	after idle [list $self Finish error]
	$self emit $line error
	error $line
    }
    method Finish {result} {
	if {[catch {fileevent $myTask readable ""} error]} {
	    $self emit $error\n error
	}
	set myLastScanResult $result
	$self history update
	if {[catch {$self finish run} error]} {
	    $self emit hook-error=$error\n error
	}
	if {[catch {close $myTask} error]} {
	    $self emit $error\n error
	}
	set myTask ""; # assert {$myTask eq $chan}
    }
    variable myFinishHook ""
    method {finish add} hook {
	lappend myFinishHook $hook
    }
    method {finish run} {} {
	foreach hook $myFinishHook {
	    uplevel #0 $hook
	}
	$self finish clear
    }
    method {finish clear} {} {
	set myFinishHook ""
    }

    option -resolution 100
    method {opt resolution} {} {
	list --resolution $options(-resolution) \
	    --y-resolution $options(-resolution)
    }
    method {opt paper} {} {
	list -x $options(-paper-width) -y $options(-paper-height) \
	    --page-width $options(-paper-width) \
	    --page-height $options(-paper-height)
    }

    #----------------------------------------
    method readable chan {
	set rc [catch {
	    if {[eof $chan]} {
		$self emit <EOF> warn
		$self Finish eof
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
		    $self Finish ok
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
    #========================================
    variable myPageHist [list]
    component myPageHistFrm
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
    #========================================
    method preview {} {
	exec -ignorestderr gthumb [file join $options(-chdir) $curBook] &
    }
    method {isbn open} {{isbn ""}} {
	if {$isbn eq ""} {
	    set isbn [$self cget -isbn]
	}
	set asin [$self isbn as_asin $isbn]
	# set url http://amazon.jp/dp/$isbn/
	set url $options(-amazon)/$asin/
	puts "Opening $url..."
	exec xdg-open $url &
    }
    method {isbn validate} isbn {
	expr {[$self isbn as_asin $isbn] ne ""}
    }
    method {isbn as_asin} isbn {
	set isbn [string map {- ""} $isbn]
	if {[string length $isbn] == 10} {
	    return [$self isbn checked10 $isbn]
	} elseif {[string length $isbn] == 13} {
	    return [$self isbn cvt13to10 $isbn]
	} else {
	    error "Invalid ISBN $isbn"
	}
    }

    method {isbn checked10} isbn {
	set calc [$self isbn ckdigit10 [split $isbn ""]]
	if {[set written [string index $isbn 9]] ne $calc} {
	    error "ISBN checkdigit mismatch! written $got calculated $calc"
	}
	set isbn
    }

    method {isbn cvt13to10} isbn {
	set main [string range $isbn 3 11]
	return $main[$self isbn ckdigit10 [split $main ""]]
    }

    method {isbn ckdigit10} isbn10 {
	set mul 10;
	set sum 0
	for {set i 0} {$i < 9} {incr i; incr mul -1} {
	    puts "$i.[lindex $isbn10 $i]"
	    incr sum [expr {[lindex $isbn10 $i] * $mul}]
	}
	set mod [expr {$sum % 11}]
	set val [expr {11 - $mod}]
	switch $val {
	    10 { return X }
	    11 { return 0 }
	    default { return $val }
	}
    }

    #========================================
    component myMessage
    method emit {msg {tag ""} args} {
	$myMessage insert end $msg $tag {*}$args
	if {[$myMessage get end-1c] ne "\n"} {
	    $myMessage insert end \n
	}
	$myMessage see end
    }

    method dputs args {
	$myMessage insert end $args\n
	if {! $options(-verbose)} return
	puts stderr $args
    }

    method console {} {
	package require tclreadline
	tclreadline::readline eofchar [list $self Quit]
	after idle tclreadline::Loop
    }

    method myvar vn {
	myvar $vn
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

    proc lmodulo {list mod i args} {
	array set dict {}
	foreach i [linsert $args 0 $i] {
	    set dict($i) 1
	}
	set result {}
	for {set i 0} {$i < [llength $list]} {incr i} {
	    if {![info exists dict([expr {$i % $mod}])]} continue
	    lappend result [lindex $list $i]
	}
	set result
    }

    proc read_file {fn args} {
	set fh [open $fn]
	set data [read $fh]
	close $fh
	set data
    }

    proc write_file {fn str} {
	set fh [open $fn w]
	# trace add variable ... close
	# fconfigure
	puts -nonewline $fh $str
	close $fh
    }
}

if {[info level] == 0 && $::argv0 eq [info script]} {
    if {![winfo exists .win]} {
	pack [scanadf .win {*}$::argv] -fill both -expand yes
    }
}

# Local Variables: **
# coding: utf-8 **
# End: **
