#! /usr/bin/env tclsh

# Tcl 8.4 doesn't support this test
if {$tcl_version == "8.4"} {
	exit 0
}

# Determine if we should be 64-bit or not
set buildflags [split [lindex $argv 1] -]
if {[lsearch -exact $buildflags "amd64"] != -1} {
	set is64bit 1
} else {
	set is64bit 0
}

if {[tcl::pkgconfig get 64bit] == $is64bit} {
	exit 0
}

puts "tcl::pkgconfig get 64 returned [tcl::pkgconfig get 64bit], but platform is 64 bit returned: $is64bit"

exit 1
