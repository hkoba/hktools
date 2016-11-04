#!/usr/bin/tclsh
# -*- coding: utf-8 -*-

package require sqlite3

# column names
proc table_info {db table} {
    set result {}
    $db eval "pragma table_info('$table')" col_info {
	lappend result $col_info(name)
    }
    set result
}

apply {{dbName} {

    sqlite3 db $dbName
    
    if {[llength [table_info db host]] == 2} {
	db eval {
	    alter table host add column geo_city text;
	    alter table host add column geo_asnum text;
	}
    }

    db transaction {
	db eval {select * from host} {
	    set res [split [exec geoiplookup $host] \n]
	    if {[llength $res] < 3} continue
	    lassign $res country city asnum
	    regsub {^GeoIP City Edition, Rev \d+: } $city {} city
	    regsub {^GeoIP ASNum Edition: } $asnum {} asnum
	    db eval {
		update host set geo_city = $city
		, geo_asnum = $asnum
		where host = $host
	    }
	}
    }
}} {*}$::argv

