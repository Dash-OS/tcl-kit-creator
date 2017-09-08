#! /usr/bin/env tclsh

if {[catch {
	set buildflags [split [lindex $argv 1] -]

	# Determine if Itcl was was requested
	## Minimal builds don't come with Itcl
	set hasitcl 1
	if {[lsearch -exact $buildflags "min"] != -1} {
		set hasitcl 0
	}

	if {!$hasitcl} {
		exit 0
	}

	package require Itcl

	exit 0
}]} {
	puts "Error in Itcl Test: $errorInfo"
	exit 1
}
