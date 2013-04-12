#!/usr/bin/env tclsh

package require sqlite3
package require snit
package require struct::list

snit::type vdbeanalyzer {
    option -file
    component myDB

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
OpenRead
Close

SetNumColumns

Rowid
Column

MoveLe
MoveGe
NotExists

Next
Prev
    }

    typevariable register_op {
IsNull
Once
Integer
Null
    }

    method explain sql {
	puts "<table border class='sqlite-explain'>"
	foreach line [$self study $sql] {
	    puts <tr>
	    set rest [lassign $line row]
	    puts "<th id='explain-$row'>$row</th>"
	    foreach col $rest {
		lassign $col op ix
		puts <td>$op
		if {$ix ne ""} {
		    puts <br><i>$ix</i>
		}
		puts </td>
	    }
	    puts </tr>
	}
	puts </table>
    }

    method study sql {
	set db [$self DB]
	set row 0
	set matrix {}
	set current 0
	$db eval "explain $sql" {
	    set cell [list [list $p1 $opcode $p2]]
	    lappend cell [if {[regexp Open $opcode]} {
		$self rootpage $p2
	    }]
	    if {$opcode in $cursor_op} {
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
	    lappend myColList [list C $num]
	    set $vn $pos
	}
    }

    method get_register num {
	set vn myRegisterDict($num)
	if {[info exists $vn]} {
	    set $vn
	} else {
	    set pos [llength $myColList]
	    lappend myColList [list C $num]
	    set $vn $pos
	}
    }

    method rootpage num {
	set db [$self DB]
	$db eval {
	    select type, name from sqlite_master where rootpage = $num
	}
    }
}

if {![info level] && [info exists ::argv0] && $::argv0 eq [info script]} {
    lassign $::argv file sql
    if {![file readable $file]} {
	error "Can't find dbfile $file"
    }
    vdbeanalyzer obj -file $file
    obj explain $sql
}
