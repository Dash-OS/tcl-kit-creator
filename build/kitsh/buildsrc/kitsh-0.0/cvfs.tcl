#! /usr/bin/env tcl

package require vfs

namespace eval ::vfs::cvfs {}

# Convience functions
proc ::vfs::cvfs::Mount {hashkey local} {
	vfs::filesystem mount $local [list ::vfs::cvfs::vfshandler $hashkey]
	catch {
		vfs::RegisterMount $local [list ::vfs::cvfs::Unmount]
	}
}

proc ::vfs::cvfs::Unmount {local} {
	vfs::filesystem unmount $local
}

# Implementation
## I/O Handlers (pass to appropriate hashkey)
namespace eval ::vfs::cvfs::data {}
proc ::vfs::cvfs::data::getChildren args {
	set hashkey [lindex $args 0]

	set cmd "::vfs::cvfs::data::${hashkey}::getChildren"
	set cmd [linsert $args 0 $cmd]

	eval $cmd
}

proc ::vfs::cvfs::data::getMetadata args {
	set hashkey [lindex $args 0]

	set cmd "::vfs::cvfs::data::${hashkey}::getMetadata"
	set cmd [linsert $args 0 $cmd]

	eval $cmd
}

proc ::vfs::cvfs::data::getData args {
	set hashkey [lindex $args 0]

	set cmd "::vfs::cvfs::data::${hashkey}::getData"
	set cmd [linsert $args 0 $cmd]

	eval $cmd
}

## VFS and Chan I/O
### Dispatchers
proc ::vfs::cvfs::vfshandler {hashkey subcmd args} {
	set cmd $args
	set cmd [linsert $cmd 0 "::vfs::cvfs::vfsop_${subcmd}" $hashkey]

	return [eval $cmd]
}

proc ::vfs::cvfs::chanhandler {hashkey subcmd args} {
	set cmd $args
	set cmd [linsert $cmd 0 "::vfs::cvfs::chanop_${subcmd}" $hashkey]

	return [eval $cmd]
}

### Actual handlers
#### Channel operation handlers
proc ::vfs::cvfs::chanop_initialize {hashkey chanId mode} {
	return [list initialize finalize watch read seek]
}

proc ::vfs::cvfs::chanop_finalize {hashkey chanId} {
	unset -nocomplain ::vfs::cvfs::chandata([list $hashkey $chanId])

	return
}

proc ::vfs::cvfs::chanop_watch {hashkey chanId eventSpec} {
	array set chaninfo $::vfs::cvfs::chandata([list $hashkey $chanId])

	set chaninfo(watching) $eventSpec

	set ::vfs::cvfs::chandata([list $hashkey $chanId]) [array get chaninfo]

	if {[lsearch -exact $chaninfo(watching) "read"] != -1} {
		after 0 [list catch "chan postevent $chanId [list {read}]"]
	}

	return
}

proc ::vfs::cvfs::chanop_read {hashkey chanId bytes} {
	array set chaninfo $::vfs::cvfs::chandata([list $hashkey $chanId])

	set pos $chaninfo(pos)
	set len $chaninfo(len)

	if {[lsearch -exact $chaninfo(watching) "read"] != -1} {
		after 0 [list catch "chan postevent $chanId [list {read}]"]
	}

	if {$pos == $len} {
		return ""
	}

	set end [expr {$pos + $bytes}]
	if {$end > $len} {
		set end $len
	}

	set data [::vfs::cvfs::data::getData $hashkey $chaninfo(file) $pos $end]

	set dataLen [string length $data]
	incr pos $dataLen

	set chaninfo(pos) $pos

	set ::vfs::cvfs::chandata([list $hashkey $chanId]) [array get chaninfo]

	return $data
}

proc ::vfs::cvfs::chanop_seek {hashkey chanId offset origin} {
	array set chaninfo $::vfs::cvfs::chandata([list $hashkey $chanId])

	set pos $chaninfo(pos)
	set len $chaninfo(len)

	switch -- $origin {
		"start" - "0" {
			set pos $offset
		}
		"current" - "1" {
			set pos [expr {$pos + $offset}]
		}
		"end" - "2" {
			set pos [expr {$len + $offset}]
		}
	}

	if {$pos < 0} {
		set pos 0
	}

	if {$pos > $len} {
		set pos $len
	}

	set chaninfo(pos) $pos
	set ::vfs::cvfs::chandata([list $hashkey $chanId]) [array get chaninfo]

	return $pos
}

#### VFS operation handlers
proc ::vfs::cvfs::vfsop_stat {hashkey root relative actualpath} {
	catch {
		set ret [::vfs::cvfs::data::getMetadata $hashkey $relative]
	}

	if {![info exists ret]} {
		vfs::filesystem posixerror $::vfs::posix(ENOENT)
	}

	return $ret
}

proc ::vfs::cvfs::vfsop_access {hashkey root relative actualpath mode} {
	set ret [::vfs::cvfs::data::getMetadata $hashkey $relative]

	if {$mode & 0x2} {
		vfs::filesystem posixerror $::vfs::posix(EROFS)
	}

	return 1
}

proc ::vfs::cvfs::vfsop_matchindirectory {hashkey root relative actualpath pattern types} {
	set ret [list]

	catch {
		array set metadata [::vfs::cvfs::data::getMetadata $hashkey $relative]
	}

	if {![info exists metadata]} {
		return [list]
	}

	if {$pattern == ""} {
		set children [list $relative]
	} else {
		set children [::vfs::cvfs::data::getChildren $hashkey $relative]
	}

	foreach child $children {
		if {$pattern != ""} {
			if {![string match $pattern $child]} {
				continue
			}
		}

		unset -nocomplain metadata
		catch {
			array set metadata [::vfs::cvfs::data::getMetadata $hashkey $child]
		}

		if {[string index $root end] == "/"} {
			set child "${root}${child}"
		} else {
			set child "${root}/${child}"
		}
		if {[string index $child end] == "/"} {
			set child [string range $child 0 end-1]
		}

		if {![info exists metadata(type)]} {
			continue
		}

		set filetype 0
		switch -- $metadata(type) {
			"directory" {
				set filetype [expr {$filetype | 0x04}]
			}
			"file" {
				set filetype [expr {$filetype | 0x10}]
			}
			"link" {
				set filetype [expr {$filetype | 0x20}]
			}
			default {
				continue
			}
		}

		if {($filetype & $types) != $types} {
			continue
		}

		lappend ret $child
	}

	return $ret
}

proc ::vfs::cvfs::vfsop_fileattributes {hashkey root relative actualpath {index -1} {value ""}} {
	set attrs [list -owner -group -permissions]

	if {$value != ""} {
		vfs::filesystem posixerror $::vfs::posix(EROFS)
	}

	if {$index == -1} {
		return $attrs
	}

	array set metadata [::vfs::cvfs::data::getMetadata $hashkey $relative]

	set attr [lindex $attrs $index]

	switch -- $attr {
		"-owner" {
			return $metadata(uid)
		}
		"-group" {
			return $metadata(gid)
		}
		"-permissions" {
			if {$metadata(type) == "directory"} {
				set metadata(mode) [expr {$metadata(mode) | 040000}]
			}

			return [format {0%o} $metadata(mode)]
		}
	}

	return -code error "Invalid index"
}

proc ::vfs::cvfs::vfsop_open {hashkey root relative actualpath mode permissions} {
	if {$mode != "" && $mode != "r"} {
		vfs::filesystem posixerror $::vfs::posix(EROFS)
	}

	catch {
		array set metadata [::vfs::cvfs::data::getMetadata $hashkey $relative]
	}

	if {![info exists metadata]} {
		vfs::filesystem posixerror $::vfs::posix(ENOENT)
	}

	if {$metadata(type) == "directory"} {
		vfs::filesystem posixerror $::vfs::posix(EISDIR)
	}

	if {[info command chan] != ""} {
		set chan [chan create [list "read"] [list ::vfs::cvfs::chanhandler $hashkey]]

		set ::vfs::cvfs::chandata([list $hashkey $chan]) [list file $relative pos 0 len $metadata(size) watching ""]

		return [list $chan]
	}

	if {[info command rechan] == ""} {
		catch {
			package require rechan
		}
	}

	if {[info command rechan] != ""} {
		set chan [rechan [list ::vfs::cvfs::chanhandler $hashkey] 2]

		set ::vfs::cvfs::chandata([list $hashkey $chan]) [list file $relative pos 0 len $metadata(size) watching ""]

		return [list $chan]
	}

	return -code error "No way to generate a channel, need either Tcl 8.5+, \"rechan\""
}

##### No-Ops since we are a readonly filesystem
proc ::vfs::cvfs::vfsop_createdirectory {args} {
	vfs::filesystem posixerror $::vfs::posix(EROFS)
}
proc ::vfs::cvfs::vfsop_deletefile {args} {
	vfs::filesystem posixerror $::vfs::posix(EROFS)
}
proc ::vfs::cvfs::vfsop_removedirectory {args} {
	vfs::filesystem posixerror $::vfs::posix(EROFS)
}
proc ::vfs::cvfs::vfsop_utime {} {
	vfs::filesystem posixerror $::vfs::posix(EROFS)
}

package provide vfs::cvfs 1.0
