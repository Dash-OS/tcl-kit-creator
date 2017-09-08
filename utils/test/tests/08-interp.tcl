#! /usr/bin/env tclsh

set newinterp [interp create]

if {[string match "interp*" $newinterp]} {
	exit 0
}

puts "Interp Name: $newinterp"
puts "Expected:    interp*"

exit 1
