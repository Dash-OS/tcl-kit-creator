#! /usr/bin/env tclsh

# Abort if we cant read the tmpfile path from the environment
if {![info exists ::env(TMPFILE)]} {
	exit 0
}

# Abort this test if we don't have vfs::zip
if {[catch {
	package require vfs::zip
}]} {
	exit 0
}

set tmpfile $::env(TMPFILE)

vfs::zip::Mount $tmpfile $tmpfile

set fd [open [file join $tmpfile main.tcl]]
set data [read $fd]
close $fd

catch {
	vfs::unmount $tmpfile
}

catch {
	file delete -force -- $tmpfile
}

if {[string match "*Hello World*" $data]} {
	exit 0
}

puts "Got:              $data"
puts "Expected (match): *Hello World*"

exit 1
