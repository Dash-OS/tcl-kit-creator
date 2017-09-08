#! /usr/bin/env tclsh

set chkversion [lindex $argv 2]

# We are unable to make a reasonable determination of the version from a CVS
# tag.  Assume it's okay.
if {[string match "cvs_*" $chkversion] || [string match "fossil_*" $chkversion]} {
	exit 0
}

if {[info patchlevel] == $chkversion} {
	exit 0
}

exit 1
