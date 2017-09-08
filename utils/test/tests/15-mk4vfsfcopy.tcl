#! /usr/bin/env tclsh

set haveMk4vfs 0
catch {
	package require vfs::mk4
	vfs::mk4::Mount $TMPFILE /TEST
	set haveMk4vfs 1
}

if {!$haveMk4vfs} {
	# This test only applies to kits that include Mk4vfs
	exit 0
}

set TMPFILE $::env(TMPFILE)

set ::fcopy_complete 0
proc fcopy_complete {args} {
	set ::fcopy_complete 1
}

set fd [open /TEST/cross.png]
fconfigure $fd -translation binary
set out [open /dev/null w]
fcopy $fd $out -command fcopy_complete
after 3000
update

if {$::fcopy_complete != 1} {
	puts "Expected:  Fcopy Complete = 1"
	puts "Got:       Fcopy Complete = $::fcopy_complete"
	exit 1
}

exit 0
