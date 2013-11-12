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

	puts {<p>Each cell means: P1 opcode P2 {P3 P4 P5}
	    <br>For Open*, table type and table name follows
</p>}
	puts "<table border class='sqlite-explain'>"
	set body [$self study $sql]
	puts <tr>
	puts <th>Addr</th>
	foreach col $myColList {
	    puts <th>$col</th>
	}
	puts </tr>
	foreach line $body {
	    puts <tr>
	    set rest [lassign $line row]
	    puts "<th id='explain-$row'>$row</th>"
	    foreach col $rest {
		lassign $col main ix
		set rest [lassign $main op p1]
		puts [subst {<td>$p1 <a href="$base#$op">$op</a> $rest}]
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
}

if {![info level] && [info exists ::argv0] && $::argv0 eq [info script]} {
    lassign $::argv file sql
    if {![file readable $file]} {
	error "Can't find dbfile $file"
    }
    vdbeanalyzer obj -file $file
    obj explain $sql
}
