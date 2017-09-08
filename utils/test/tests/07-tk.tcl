#! /usr/bin/env tclsh

# Determine if we should have Tk
set buildflags [split [lindex $argv 1] -]
foreach flag [list notk min] {
	if {[lsearch -exact $buildflags $flag] != -1} {
		exit 0
	}
}

package require Tk

label .l
pack .l

if {[winfo children .] == ".l"} {
	exit 0
}

puts "Winfo Children: [winfo children .]"

exit 1
