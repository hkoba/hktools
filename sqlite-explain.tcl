#!/usr/bin/env tclsh

package require sqlite3
package require snit
package require struct::list

snit::type vdbeanalyzer {
    option -file
    component myDB

    option -debug no
    option -mode ""

    method DB {} {
	if {$myDB eq ""} {
	    sqlite3 [set myDB $self.db] $options(-file)
	}
	set myDB
    }

    variable myCursorDict -array {}
    variable myRegisterDict -array {}
    variable myColList {}

    typevariable cursor_op {
Open*
Close

SetNumColumns

Column
Count
Delete
Found

Idx*
Insert
IsUnique

MoveLe
MoveGe
NotExists
NotFound
NullRow

NewRowid

Next
Prev
Rewind

RowData
Rowid
RowKey

Seek*

Sequence

Sorter*

VColumn
VFilter
VNext
VOpen

Halt
    }

    typevariable register_op {
IsNull
Once
Integer
Null
    }

    option -docbase http://www.sqlite.org/opcode.html
    method explain sql {
	set base $options(-docbase)

	puts {<!doctype html>
	    <head>
	    <style>
	    .for-idx, .op-seek {
		background: rgb(107,255,131);
	    }

	    .op-next, .op-prev { background: red; }
	    .op-close { background: rgb(249,58,65); }

	    .op-found, .op-notfound,
	    .op-seekge, .op-seekgt, .op-seeklt, .op-seekle,
	    .op-idxge, .op-idxgt, .op-idxlt, .op-idxle {
		background: rgb(103,192,189);
	    }

	    small { font-size: 70%; }
	    th, td { width: 200px; }
	    th.addr { width: 5em; }
	    </style>
	    <body>
	}

	puts [subst {<h2>SQL</h2><code><pre>$sql</pre></code>}]

	puts "<h2>.explain</h2>"
	puts {<p>Each cell means: P1 opcode <small>P2 {P3 P4 P5}</small>
	    <br>For Open*, table type and table name follows
</p>}
	puts "<table border class='sqlite-explain'>"
	set body [$self study $sql]
	puts <tr>
	puts {<th class="addr">Addr</th>}
	foreach col $myColList {
	    puts <th>$col</th>
	}
	puts </tr>
	foreach line $body {
	    puts <tr>
	    set rest [lassign $line row]
	    puts [subst {<th id="explain-$row" class="addr">$row</th>}]
	    foreach col $rest {
		lassign $col main ix
		set rest [lassign $main op p1]
		set cls ""
		if {$op eq "OpenRead" && [lindex $ix 0] eq "index"} {
		    append cls " for-idx"
		}
		set lower [string tolower $op]
		puts [subst {<td class="op-$lower $cls">$p1 <a href="$base#$op">$op</a> <small>$rest</small>}]
		if {$ix ne ""} {
		    puts <br><i>$ix</i>
		}
		puts </td>
	    }
	    puts </tr>
	}
	puts </table>
    }

    proc lglobmember {list item} {
	foreach i $list {
	    if {[string match $i $item]} {
		return 1
	    }
	}
	return 0
    }

    method study sql {
	set db [$self DB]
	set row 0
	set matrix {}
	set current 0
	$db eval "explain $sql" {
	    set main [list $opcode $p1 $p2]
	    if {$p3 != 0 || $p4 ne "" || $p5 ne "00"} {
		lappend main [list $p3 $p4 $p5]
	    }
	    set cell [list $main]
	    lappend cell [if {[regexp {^Open(Read|Write)} $opcode]} {
		$self rootpage $p2
	    }]
	    if {[lglobmember $cursor_op $opcode]} {
		set current [$self get_cursor $p1]
	    }
	    set line [struct::list repeat [expr {$current+1}] {}]
	    lset line $current $cell
	    lappend matrix [linsert $line 0 $row]
	    incr row
	}
	set matrix
    }

    method get_cursor num {
	set vn myCursorDict($num)
	if {[info exists $vn]} {
	    set $vn
	} else {
	    set pos [llength $myColList]
	    lappend myColList [list Cursor $num]
	    set $vn $pos
	}
    }

    method get_register num {
	set vn myRegisterDict($num)
	if {[info exists $vn]} {
	    set $vn
	} else {
	    set pos [llength $myColList]
	    lappend myColList [list Reg $num]
	    set $vn $pos
	}
    }

    method rootpage num {
	set db [$self DB]
	$db eval {
	    select type, name from sqlite_master where rootpage = $num
	}
    }
    
    method attach {dbFile args} {
        foreach dbFile [list $dbFile {*}$args] {
            set dbName [file rootname [file tail $dbFile]]
            if {$options(-debug)} {
                puts "Attaching $dbFile as $dbName"
            }
            [$self DB] eval [format {attach $dbFile as %s} $dbName]
        }
    }
    
    method query-plan sql {
	set db [$self DB]
        puts [join [list selectid order from detail] \t]
	$db eval "explain query plan $sql" {
            puts [join [list $selectid $order $from $detail] \t]
        }
    }

    method raw-explain sql {
	set db [$self DB]
        puts [join [list addr opcode p1 p2 p3 p4 p5 comment] \t]
	$db eval "explain $sql" {
            puts [join [list $addr $opcode $p1 $p2 $p3 $p4 $p5 $comment] \t]
        }
    }
}

namespace eval vdbeanalyzer {
    proc posix-getopt {argVar {dict ""} {shortcut ""}} {
	upvar 1 $argVar args
	set result {}
	while {[llength $args]} {
	    if {![regexp ^- [lindex $args 0]]} break
	    set args [lassign $args opt]
	    if {$opt eq "--"} break
	    if {[regexp {^-(-no)?(-\w[\w\-]*)(=(.*))?} $opt \
		     -> no name eq value]} {
		if {$no ne ""} {
		    set value no
		} elseif {$eq eq ""} {
		    set value [expr {1}]
		}
	    } elseif {[dict exists $shortcut $opt]} {
		set name [dict get $shortcut $opt]
		set value [expr {1}]
	    } else {
		error "Can't parse option! $opt"
	    }
	    lappend result $name $value
	    if {[dict exists $dict $name]} {
		dict unset dict $name
	    }
	}

	list {*}$dict {*}$result
    }
}

if {![info level] && [info exists ::argv0] && $::argv0 eq [info script]} {
    set opts [vdbeanalyzer::posix-getopt ::argv]
    if {[llength $::argv] < 2} {
        error "Usage: [info script] DBFILE ?DBFILE..? SQL"
    }
    set file [lindex $::argv 0]
    set sql [lindex $::argv end]
    set attachedFiles [lrange $::argv 1 end-1]
    if {![file readable $file]} {
	error "Can't find dbfile $file"
    }
    vdbeanalyzer obj {*}$opts -file $file
    if {[llength $attachedFiles]} {
        obj attach {*}$attachedFiles
    }
    if {[set mode [obj cget -mode]] ne ""} {
        obj $mode $sql
    } else {
        obj explain $sql
    }
}
