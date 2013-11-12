#!/usr/bin/env tclsh
# -*- coding: utf-8 -*-
package require sqlite3
package require snit
package require struct::list

snit::type ::sqlite_dumper {
    option -debug 0
    option -outfh stdout
    option -output

    option -db
    option -dbfile
    component myDB -public db

    option -begin yes
    option -create yes
    option -delete yes

    option -timeout 300
    option -max-retry 10
    variable myRetryCnt 0

    option -lock deferred;# immediate

    option -encoding utf-8
    option -translation auto

    constructor args {
	$self configurelist $args
	$self _connect_db
    }

    #========================================
    method _connect_db {} {
	if {$options(-db) ne ""} {
	    set myDB $options(-db)
	} elseif {$options(-dbfile) ne ""} {
	    sqlite3 [set myDB $self.db] $options(-dbfile)
	} else {
	    sqlite3 [set myDB $self.db]
	}

	if {$options(-timeout) > 0} {
	    $myDB timeout $options(-timeout)
	}
	if {$options(-max-retry) > 0} {
	    $myDB busy [list $self retry]
	}
    }

    method dump {{tables ""} args} {
	$myDB transaction $options(-lock) {
	    if {$tables eq ""} {
		set tables [$myDB eval {
		    select name from sqlite_master
		    where sql not null and type = 'table'
		}]
	    } else {
		foreach name $tables {
		    $self table_info $name
		}
	    }

	    # open output here (to avoid empty file)
	    $self ensure-output
	    if {$options(-begin)} {
		puts $options(-outfh) "BEGIN;"
	    }
	    foreach name $tables {
		$self dump_table $name
	    }
	    if {$options(-begin)} {
		puts $options(-outfh) "COMMIT;"
	    }
	    $self finalize-output
	}
    }

    #========================================

    method retry args {
	if {[incr myRetryCnt] <= $options(-max-retry)} {
	    if {$options(-timeout) > 0} {
		after $options(-timeout)
	    }
	    $self notify retry
	    return 0
	} else {
	    return 1
	}
    }

    method {notify retry} {} {
	puts -nonewline stderr .
	flush stderr
    }

    #========================================
    proc map-string {string args} {
	string map $args $string
    }

    proc sqlite_quote string {
        # See: http://www.sqlite.org/lang_expr.html
        # A string constant is formed by enclosing the string
        # in single quotes ('). A single quote within the string
        # can be encoded by putting two single quotes in a row
        # - as in Pascal. C-style escapes using the backslash character
        # are not supported because they are not standard SQL.
	regsub -all {'} $string {''}
    }

    proc value value {set value}
}

snit::method ::sqlite_dumper finalize-output {} {
    if {$options(-outfh) eq ""} return
    flush $options(-outfh)
    if {$options(-outfh) ne "stdout"} {
	close $options(-outfh)
    }
}

snit::method ::sqlite_dumper ensure-output {} {
    if {$options(-output) eq ""} {
	set options(-outfh) stdout
    } elseif {$options(-outfh) eq ""
	      || $options(-outfh) eq "stdout"} {

	set options(-outfh) [open $options(-output) w]
	fconfigure $options(-outfh) -encoding $options(-encoding)\
	    -translation $options(-translation)
    } else {
	error "You can't use -output and -outfh at once!"
    }
}

snit::method ::sqlite_dumper dump_table {table} {
    $myDB transaction $options(-lock) {
	if {$options(-create)} {
	    $myDB eval {select sql from sqlite_master where name = $table} {
		regsub {^CREATE TABLE } $sql {CREATE TABLE if not exists } sql
		puts $options(-outfh) "$sql;"
	    }
	}
	if {$options(-delete)} {
	    puts $options(-outfh) "DELETE FROM $table;"
	}
	set columns [join [struct::list mapfor c [$self table_info $table] {
	    value quote($c)
	}] ||','||]
	set query [string map [list @table@ $table @columns@ $columns] {
	    SELECT 'INSERT INTO ' || '@table@' ||
	    ' VALUES(' || @columns@ || ')' as sql from @table@;
	}]
	if {$options(-debug) >= 2} {
	    puts query=$query
	}
	$myDB eval $query {
	    puts $options(-outfh) "$sql;"
	}
    }
}

snit::method ::sqlite_dumper table_info table {
    set columns {}
    $myDB eval "PRAGMA table_info($table)" {
	lappend columns $name
    }
    if {![llength $columns]} {
	error "No such table! $table"
    }
    set columns
}

snit::method ::sqlite_dumper {where tables} tables {
    if {$tables eq ""} {
	return
    }
    set values ""
    foreach tab $tables {
	lappend values '[sqlite_quote $tab]'
    }
    map-string {name in (@values@)} @values@ [join $values ", "]
}

#========================================
# 制限付きの、 posix long option parser.
proc ::sqlite_dumper::posix-getopt {argVar {dict ""} {shortcut ""}} {
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

if {![info level] && [info script] eq $::argv0} {
    set opts [::sqlite_dumper::posix-getopt ::argv]
    set tables [lassign $::argv dbfile]
    sqlite_dumper dumper -dbfile $dbfile {*}$opts
    
    # puts debug=[dumper cget -debug]
    if {[set rc [catch {dumper dump $tables} error]]} {
	set ei $::errorInfo
	if {[dumper cget -debug]} {
	    puts stderr $ei
	} else {
	    puts stderr $error
	}
	exit 1
    }
}
