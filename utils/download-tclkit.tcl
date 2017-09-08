#!/usr/bin/env tclsh
# Tclkit Downloader v0.2.2 -- download Tclkits created with the KitCreator
# Web Interface. Works with Tcl 8.5+ and Jim Tcl v0.75+. This script requires
# that cURL be available through [exec curl].
# Copyright (C) 2016, dbohdan.
# License: MIT.
proc download url {
    if {![string match */buildinfo $url]} {
        # Guess at what the buildinfo URL might be if we are given, e.g., a
        # building page URL.
        set url [string map {/building {}} $url]
        set checksum {}
        foreach piece [split $url /] {
            if {[regexp {^[a-z0-9]{40}$} $piece checksum]} {
                break
            }
        }
        if {$checksum eq {}} {
            error "can't determine how to get the from the URL \"$url\" to the\
                    buildinfo"
        }
        set url [regexp -inline "^.*$checksum" $url]/buildinfo
    }

    set buildInfo [exec curl -s $url]

    set filename [dict get $buildInfo filename]
    append filename -[dict get $buildInfo tcl_version]
    append filename -[dict get $buildInfo platform]

    if {[llength [dict get $buildInfo packages]] > 0} {
        foreach option {staticpkgs threaded debug} {
            if {[dict exists $buildInfo options $option] &&
                    [dict get $buildInfo options $option]} {
                append filename -$option
            }
        }
        append filename -[join [dict get $buildInfo packages] -]
    }

    set tail [file tail $url]
    # We can't use [file dirname] here because it will transform
    # "http://example.com/" into "http:/example.com/".
    set baseUrl [string range $url 0 end-[string length $tail]]
    if {[string index $baseUrl end] ne {/}} {
        append baseUrl /
    }
    set tclkit $baseUrl[dict get $buildInfo filename]

    puts "Downloading $tclkit to $filename..."
    exec curl -o $filename $tclkit >@ stdout 2>@ stderr

    catch {exec chmod +x $filename}
}

set url [lindex $argv 0]
if {$url eq {}} {
    puts "usage: $argv0 url"
    puts {The URL should be a KitCreator Web Interface buildinfo page.\
            If it is instead, e.g., a building page or a direct Tclkit download\
            URL, the script will try to guess where the buildinfo is.}
} else {
    download $url
}
