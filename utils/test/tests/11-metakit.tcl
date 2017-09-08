#! /usr/bin/env tclsh

set buildflags [split [lindex $argv 1] -]

# This test works implicitly on Tclkits without Metakit4
foreach flag [list nomk4 min] {
	if {[lsearch -exact $buildflags $flag] != -1} {
		exit 0
	}
}

catch {
	file delete -force datafile.mk
}

set testval "<Not Found>"
set errorInfo_save "<No Error>"
if {[catch {
	package require Mk4tcl

	mk::file open db datafile.mk
	mk::view layout db.test {first second}
	mk::row append db.test first Joe second Bob
	mk::file commit db
	mk::file close db

	mk::file open db datafile.mk
	set testval [mk::get db.test!0 first]
	mk::file close db
}]} {
	set errorInfo_save $errorInfo
}

catch {
	file delete -force datafile.mk
}

if {$testval == "Joe"} {
	exit 0
}

puts "Returned: $testval"
puts "Expected: Joe"
puts "Error   : $errorInfo_save"

exit 1
