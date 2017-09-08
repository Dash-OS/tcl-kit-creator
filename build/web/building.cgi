#! /usr/bin/env tclsh

set outdir "/web/customers/kitcreator.rkeene.org/kits"
set key ""
if {[info exists ::env(PATH_INFO)]} {
	set key [lindex [split $::env(PATH_INFO) "/"] 1]
}

set status "Unknown"
set terminal 0
if {![regexp {^[0-9a-f]+$} $key]} {
	set status "Invalid Key"

	unset key
}

if {[info exists key]} {
	set workdir [file join $outdir $key]
}

if {[info exists workdir]} {
	if {[file exists $workdir]} {
		set fd [open [file join $workdir buildinfo]]
		set buildinfo_list [gets $fd]
		close $fd
		array set buildinfo $buildinfo_list
		set filename $buildinfo(filename)

		set outfile [file join $workdir $filename]
		set logfile "${outfile}.log"
	} else {
		set status "Queued"
	}
}

if {[info exists buildinfo]} {
	set description "Tcl $buildinfo(tcl_version)"
	append description ", KitCreator $buildinfo(kitcreator_version)"
	append description ", Platform $buildinfo(platform)"

	foreach {option value} $buildinfo(options) {
		switch -- $option {
			"kitdll" {
				if {$value} {
					append description ", Built as a Library"
				}
			}
			"dynamictk" {
				if {$value} {
					if {[lsearch -exact $buildinfo(packages) "tk"] != -1} {
						append description ", Forced Tk Dynamic Linking"
					}
				}
			}
			"threaded" {
				if {$value} {
					append description ", Threaded"
				} else {
					append description ", Unthreaded"
				}
			}
			"debug" {
				if {$value} {
					append description ", With Symbols"
				}
			}
			"minbuild" {
				if {$value} {
					append description ", Without Tcl pkgs/ and all encodings"
				}
			}
			"staticlibssl" {
				if {$value} {
					append description ", Statically linked to LibSSL"
				}
			}
			"staticpkgs" {
				if {$value} {
					append description ", With Tcl 8.6+ pkgs/ directory all packages statically linked in"
				}
			}
			"storage" {
				switch -- $value {
					"mk4" {
						append description ", Metakit-based"
					}
					"zip" {
						append description ", Zip-kit"
					}
					"cvfs" {
						append description ", Static Storage"
					}
				}
			}
		}
	}

	if {[llength $buildinfo(packages)] > 0} {
		append description ", Packages: [join $buildinfo(packages) {, }]"
	} else {
		append description ", No packages"
	}
}

if {[info exists outfile]} {
	if {[file exists $outfile]} {
		set status "Complete"
		set terminal 1

		set url "http://kitcreator.rkeene.org/kits/$key/$filename"
	} elseif {[file exists "${outfile}.buildfail"]} {
		set status "Failed"
		set terminal 1
	} else {
		set status "Building"
	}
}

puts "Content-Type: text/html"
if {[info exists url]} {
	# Use a refresh here instead of a "Location" so that
	# the client can see the page
	puts "Refresh: 0;url=$url"
} else {
	if {!$terminal} {
		puts "Refresh: 30;url=."
	}
}
puts ""
puts "<html>"
puts "\t<head>"
puts "\t\t<title>KitCreator, Web Interface</title>"
puts "\t</head>"
puts "\t<body>"
puts "\t\t<h1>KitCreator Web Interface</h1>"
puts "\t\t<p><b>Status:</b> $status"
if {[info exists url]} {
	puts "\t\t<p><b>URL:</b> <a href=\"$url\">$url</a>"
}
if {[info exists description]} {
	puts "\t\t<p><b>Description:</b> $description"
}
if {[info exists logfile]} {
	catch {
		set fd [open $logfile]
		set logdata [read $fd]
		close $fd


		puts "\t\t<p><b>Log:</b><pre>\n$logdata</pre>"
	}
}
puts "\t</body>"
puts "</html>"
