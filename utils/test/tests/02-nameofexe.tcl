#! /usr/bin/env tclsh

set outputname [lindex $argv 0]
set buildflags [split [lindex $argv 1] -]

# If we built a KitDLL, the executable name will be {kitname}-tclsh
if {[lsearch -exact $buildflags "kitdll"] != -1} {
	set outputname "${outputname}-tclsh"
}

if {[info nameofexecutable] == $outputname} {
	exit 0
}

# Under Wine, the drive letter is added
if {[info nameofexecutable] == "Z:$outputname"} {
	exit 0
}

puts "Info NameOfExe: [info nameofexecutable]"
puts "Expected:       $outputname"

exit 1
