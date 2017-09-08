#!/usr/bin/env tclsh

# Open some file inside the tclkit that will be stored in compressed form
set fd [open [file join $::tcl_library init.tcl]]

gets $fd line1

if {[catch {seek $fd 0} result]} {
    puts "Got:      $result"
    puts "Expected: <No Error>"
    exit 1
}

gets $fd str

if {[string equal $str $line1]} {
    exit 0
}

puts "Got:      $str"
puts "Expected: $line1"

exit 1
