# Removed provision of the backward compatible name. Moved to separate
# file/package.

package require vfs

# Using the vfs, memchan and Trf extensions, we ought to be able
# to write a Tcl-only zip virtual filesystem.  What we have below
# is basically that.

namespace eval vfs::zip {}

# Used to execute a zip archive.  This is rather like a jar file
# but simpler.  We simply mount it and then source a toplevel
# file called 'main.tcl'.
proc vfs::zip::Execute {zipfile} {
    Mount $zipfile $zipfile
    source [file join $zipfile main.tcl]
}

proc vfs::zip::Mount {zipfile local} {
    set fd [::zip::open [::file normalize $zipfile]]
    vfs::filesystem mount $local [list ::vfs::zip::handler $fd]
    # Register command to unmount
    vfs::RegisterMount $local [list ::vfs::zip::Unmount $fd]
    return $fd
}

proc vfs::zip::Unmount {fd local} {
    vfs::filesystem unmount $local
    ::zip::_close $fd
}

proc vfs::zip::handler {zipfd cmd root relative actualpath args} {
    #::vfs::log [list $zipfd $cmd $root $relative $actualpath $args]
    if {$cmd == "matchindirectory"} {
	eval [list $cmd $zipfd $relative $actualpath] $args
    } else {
	eval [list $cmd $zipfd $relative] $args
    }
}

proc vfs::zip::attributes {zipfd} { return [list "state"] }
proc vfs::zip::state {zipfd args} {
    vfs::attributeCantConfigure "state" "readonly" $args
}

# If we implement the commands below, we will have a perfect
# virtual file system for zip files.

proc vfs::zip::matchindirectory {zipfd path actualpath pattern type} {
    #::vfs::log [list matchindirectory $path $actualpath $pattern $type]

    # This call to zip::getdir handles empty patterns properly as asking
    # for the existence of a single file $path only
    set res [::zip::getdir $zipfd $path $pattern]
    #::vfs::log "got $res"
    if {![string length $pattern]} {
	if {![::zip::exists $zipfd $path]} { return {} }
	set res [list $actualpath]
	set actualpath ""
    }

    set newres [list]
    foreach p [::vfs::matchCorrectTypes $type $res $actualpath] {
	lappend newres [file join $actualpath $p]
    }
    #::vfs::log "got $newres"
    return $newres
}

proc vfs::zip::stat {zipfd name} {
    #::vfs::log "stat $name"
    ::zip::stat $zipfd $name sb
    #::vfs::log [array get sb]
    array get sb
}

proc vfs::zip::access {zipfd name mode} {
    #::vfs::log "zip-access $name $mode"
    if {$mode & 2} {
	vfs::filesystem posixerror $::vfs::posix(EROFS)
    }
    # Readable, Exists and Executable are treated as 'exists'
    # Could we get more information from the archive?
    if {[::zip::exists $zipfd $name]} {
	return 1
    } else {
	error "No such file"
    }
    
}

proc vfs::zip::open {zipfd name mode permissions} {
    #::vfs::log "open $name $mode $permissions"
    # return a list of two elements:
    # 1. first element is the Tcl channel name which has been opened
    # 2. second element (optional) is a command to evaluate when
    #    the channel is closed.

    switch -- $mode {
	"" -
	"r" {
	    if {![::zip::exists $zipfd $name]} {
		vfs::filesystem posixerror $::vfs::posix(ENOENT)
	    }
	    
	    ::zip::stat $zipfd $name sb

            if {$sb(ino) == -1} {
                vfs::filesystem posixerror $::vfs::posix(EISDIR)
            }

	    set nfd [vfs::memchan]
	    fconfigure $nfd -translation binary

	    seek $zipfd $sb(ino) start
	    zip::Data $zipfd sb data

	    puts -nonewline $nfd $data

	    fconfigure $nfd -translation auto
	    seek $nfd 0
	    return [list $nfd]
	}
	default {
	    vfs::filesystem posixerror $::vfs::posix(EROFS)
	}
    }
}

proc vfs::zip::createdirectory {zipfd name} {
    #::vfs::log "createdirectory $name"
    vfs::filesystem posixerror $::vfs::posix(EROFS)
}

proc vfs::zip::removedirectory {zipfd name recursive} {
    #::vfs::log "removedirectory $name"
    vfs::filesystem posixerror $::vfs::posix(EROFS)
}

proc vfs::zip::deletefile {zipfd name} {
    #::vfs::log "deletefile $name"
    vfs::filesystem posixerror $::vfs::posix(EROFS)
}

proc vfs::zip::fileattributes {zipfd name args} {
    #::vfs::log "fileattributes $args"
    switch -- [llength $args] {
	0 {
	    # list strings
	    return [list]
	}
	1 {
	    # get value
	    set index [lindex $args 0]
	    return ""
	}
	2 {
	    # set value
	    set index [lindex $args 0]
	    set val [lindex $args 1]
	    vfs::filesystem posixerror $::vfs::posix(EROFS)
	}
    }
}

proc vfs::zip::utime {fd path actime mtime} {
    vfs::filesystem posixerror $::vfs::posix(EROFS)
}

# Below copied from TclKit distribution

#
# ZIP decoder:
#
# Format of zip file:
# [ Data ]* [ TOC ]* EndOfArchive
#
# Note: TOC is refered to in ZIP doc as "Central Archive"
#
# This means there are two ways of accessing:
#
# 1) from the begining as a stream - until the header
#	is not "PK\03\04" - ideal for unzipping.
#
# 2) for table of contents without reading entire
#	archive by first fetching EndOfArchive, then
#	just loading the TOC
#

namespace eval zip {
    array set methods {
	0	{stored - The file is stored (no compression)}
	1	{shrunk - The file is Shrunk}
	2	{reduce1 - The file is Reduced with compression factor 1}
	3	{reduce2 - The file is Reduced with compression factor 2}
	4	{reduce3 - The file is Reduced with compression factor 3}
	5	{reduce4 - The file is Reduced with compression factor 4}
	6	{implode - The file is Imploded}
	7	{reserved - Reserved for Tokenizing compression algorithm}
	8	{deflate - The file is Deflated}
	9	{reserved - Reserved for enhanced Deflating}
	10	{pkimplode - PKWARE Date Compression Library Imploding}
    }
    # Version types (high-order byte)
    array set systems {
	0	{dos}
	1	{amiga}
	2	{vms}
	3	{unix}
	4	{vm cms}
	5	{atari}
	6	{os/2}
	7	{macos}
	8	{z system 8}
	9	{cp/m}
	10	{tops20}
	11	{windows}
	12	{qdos}
	13	{riscos}
	14	{vfat}
	15	{mvs}
	16	{beos}
	17	{tandem}
	18	{theos}
    }
    # DOS File Attrs
    array set dosattrs {
	1	{readonly}
	2	{hidden}
	4	{system}
	8	{unknown8}
	16	{directory}
	32	{archive}
	64	{unknown64}
	128	{normal}
    }

    proc u_short {n}  { return [expr { ($n+0x10000)%0x10000 }] }
}

proc zip::DosTime {date time} {
    # The pre-VFS environment will not have access to "clock", so don't even
    # bother
    return 0
}


proc zip::Data {fd arr {varPtr ""} {verify 0}} {
    upvar 1 $arr sb

    if { $varPtr != "" } {
	upvar 1 $varPtr data
    }

    set buf [read $fd 30]
    set n [binary scan $buf A4sssssiiiss \
		hdr sb(ver) sb(flags) sb(method) \
		time date \
		sb(crc) sb(csize) sb(size) flen elen]

    if { ![string equal "PK\03\04" $hdr] } {
	binary scan $hdr H* x
	error "bad header: $x"
    }
    set sb(ver)		[u_short $sb(ver)]
    set sb(flags)	[u_short $sb(flags)]
    set sb(method)	[u_short $sb(method)]
    set sb(mtime)	[DosTime $date $time]

    set sb(name) [read $fd [u_short $flen]]
    set sb(extra) [read $fd [u_short $elen]]

    if { $varPtr == "" } {
	seek $fd $sb(csize) current
    } else {
	# Added by Chuck Ferril 10-26-03 to fix reading of OpenOffice
	#  .sxw files. Any files in the zip that had a method of 8
	#  (deflate) failed here because size and csize were zero.
	#  I'm not sure why the above computes the size and csize
	#  wrong, but stat appears works properly. I originally
	#  checked for csize of zero, but adding this change didn't
	#  appear to break the none deflated file access and seemed
	#  more natural.
 	zip::stat $fd $sb(name) sb

	set data [read $fd $sb(csize)]
    }

    if { $sb(flags) & 0x4 } {
	# Data Descriptor used
	set buf [read $fd 12]
	binary scan $buf iii sb(crc) sb(csize) sb(size)
    }


    if { $varPtr == "" } {
	return ""
    }

    if { $sb(method) != 0 } {
	if { [catch {
	    set data [vfs::zip -mode decompress -nowrap 1 $data]
	} err] } {
	    ::vfs::log "$sb(name): inflate error: $err"
	    binary scan $data H* x
	    ::vfs::log $x
	}
    }
    return
    if { $verify } {
	set ncrc [vfs::crc $data]
	if { $ncrc != $sb(crc) } {
	    tclLog [format {%s: crc mismatch: expected 0x%x, got 0x%x} \
		    $sb(name) $sb(crc) $ncrc]
	}
    }
}

proc zip::EndOfArchive {fd arr} {
    upvar 1 $arr cb

    # [SF Tclvfs Bug 1003574]. Do not seek over beginning of file.
    seek $fd 0 end

    # Just looking in the last 512 bytes may be enough to handle zip
    # archives without comments, however for archives which have
    # comments the chunk may start at an arbitrary distance from the
    # end of the file. So if we do not find the header immediately
    # we have to extend the range of our search, possibly until we
    # have a large part of the archive in memory. We can fail only
    # after the whole file has been searched.

    set sz  [tell $fd]
    if {[info exists ::zip::max_header_seek]} {
        if {$::zip::max_header_seek < $sz} {
            set sz $::zip::max_header_seek
        }
    } 
    set len 512
    set at  512
    while {1} {
	if {$sz < $at} {set n -$sz} else {set n -$at}

	seek $fd $n end
	set hdr [read $fd $len]
	set pos [string first "PK\05\06" $hdr]
	if {$pos == -1} {
	    if {$at >= $sz} {
		return -code error "no header found"
	    }
	    set len 540 ; # after 1st iteration we force overlap with last buffer
	    incr at 512 ; # to ensure that the pattern we look for is not split at
	    #           ; # a buffer boundary, nor the header itself
	} else {
	    break
	}
    }

    set hdr [string range $hdr [expr $pos + 4] [expr $pos + 21]]

    set seekstart [expr {[tell $fd] - 512}]
    if {$seekstart < 0} {
        set seekstart 0
    }
    set pos [expr {$seekstart + $pos}]

    binary scan $hdr ssssiis \
	cb(ndisk) cb(cdisk) \
	cb(nitems) cb(ntotal) \
	cb(csize) cb(coff) \
	cb(comment)

    set cb(ndisk)	[u_short $cb(ndisk)]
    set cb(nitems)	[u_short $cb(nitems)]
    set cb(ntotal)	[u_short $cb(ntotal)]
    set cb(comment)	[u_short $cb(comment)]

    # Compute base for situations where ZIP file
    # has been appended to another media (e.g. EXE)
    set base            [expr { $pos - $cb(csize) - $cb(coff) }]
    if {$base < 0} {
        set base 0
    }
    set cb(base)	$base
}

proc zip::TOC {fd arr} {
    upvar #0 zip::$fd cb
    upvar 1 $arr sb

    set buf [read $fd 46]

    binary scan $buf A4ssssssiiisssssii hdr \
      sb(vem) sb(ver) sb(flags) sb(method) time date \
      sb(crc) sb(csize) sb(size) \
      flen elen clen sb(disk) sb(attr) \
      sb(atx) sb(ino)

    set sb(ino) [expr {$cb(base) + $sb(ino)}]

    if { ![string equal "PK\01\02" $hdr] } {
	binary scan $hdr H* x
	error "bad central header: $x"
    }

    foreach v {vem ver flags method disk attr} {
	set cb($v) [u_short [set sb($v)]]
    }

    set sb(mtime) [DosTime $date $time]
    set sb(mode) [expr { ($sb(atx) >> 16) & 0xffff }]
    if { ( $sb(atx) & 0xff ) & 16 } {
	set sb(type) directory
    } else {
	set sb(type) file
    }
    set sb(name) [read $fd [u_short $flen]]
    set sb(extra) [read $fd [u_short $elen]]
    set sb(comment) [read $fd [u_short $clen]]
}

proc zip::open {path} {
    set fd [::open $path]
    
    if {[catch {
	upvar #0 zip::$fd cb
	upvar #0 zip::$fd.toc toc

	fconfigure $fd -translation binary ;#-buffering none
	
	zip::EndOfArchive $fd cb

	seek $fd [expr {$cb(base) + $cb(coff)}] start

	set toc(_) 0; unset toc(_); #MakeArray
	
	for { set i 0 } { $i < $cb(nitems) } { incr i } {
	    zip::TOC $fd sb
	    
	    set sb(depth) [llength [file split $sb(name)]]
	    
	    set name [string tolower $sb(name)]
	    set toc($name) [array get sb]
	    FAKEDIR toc [file dirname $name]
	}
    } err]} {
	close $fd
	return -code error $err
    }

    return $fd
}

proc zip::FAKEDIR {arr path} {
    upvar 1 $arr toc

    if { $path == "."} { return }


    if { ![info exists toc($path)] } {
	# Implicit directory
	lappend toc($path) \
		name $path \
		type directory mtime 0 size 0 mode 0777 \
		ino -1 depth [llength [file split $path]]
    }
    FAKEDIR toc [file dirname $path]
}

proc zip::exists {fd path} {
    #::vfs::log "$fd $path"
    if {$path == ""} {
	return 1
    } else {
	upvar #0 zip::$fd.toc toc
	info exists toc([string tolower $path])
    }
}

proc zip::stat {fd path arr} {
    upvar #0 zip::$fd.toc toc
    upvar 1 $arr sb

    set name [string tolower $path]
    if { $name == "" || $name == "." } {
	array set sb {
	    type directory mtime 0 size 0 mode 0777 
	    ino -1 depth 0 name ""
	}
    } elseif {![info exists toc($name)] } {
	return -code error "could not read \"$path\": no such file or directory"
    } else {
	array set sb $toc($name)
    }
    set sb(dev) -1
    set sb(uid)	-1
    set sb(gid)	-1
    set sb(nlink) 1
    set sb(atime) $sb(mtime)
    set sb(ctime) $sb(mtime)
    return ""
}

# Treats empty pattern as asking for a particular file only
proc zip::getdir {fd path {pat *}} {
    #::vfs::log [list getdir $fd $path $pat]
    upvar #0 zip::$fd.toc toc

    if { $path == "." || $path == "" } {
	set path [string tolower $pat]
    } else {
	set path [string tolower $path]
	if {$pat != ""} {
	    append path /[string tolower $pat]
	}
    }
    set depth [llength [file split $path]]

    #puts stderr "getdir $fd $path $depth $pat [array names toc $path]"
    if {$depth} {
	set ret {}
	foreach key [array names toc $path] {
	    if {[string index $key end] == "/"} {
		# Directories are listed twice: both with and without
		# the trailing '/', so we ignore the one with
		continue
	    }
	    array set sb $toc($key)

	    if { $sb(depth) == $depth } {
		if {[info exists toc(${key}/)]} {
		    array set sb $toc(${key}/)
		}
		lappend ret [file tail $sb(name)]
	    } else {
		#::vfs::log "$sb(depth) vs $depth for $sb(name)"
	    }
	    unset sb
	}
	return $ret
    } else {
	# just the 'root' of the zip archive.  This obviously exists and
	# is a directory.
	return [list {}]
    }
}

proc zip::_close {fd} {
    variable $fd
    variable $fd.toc
    unset $fd
    unset $fd.toc
    ::close $fd
}

# use zlib to define zip and crc if available
if {[llength [info command vfs::zip]] == 0 && [llength [info command zlib]] || ![catch {load "" zlib}]} {
	proc vfs::zip {flag value args} {
		switch -glob -- "$flag $value" {
			{-mode d*} { set mode decompress }
			{-mode c*} { set mode compress }
			default { error "usage: zip -mode {compress|decompress} data" }
		}

		# kludge to allow "-nowrap 1" as second option, 5-9-2002
		if {[llength $args] > 2 && [lrange $args 0 1] eq "-nowrap 1"} {
			if {$mode eq "compress"} {
				set mode deflate
			} else {
				set mode inflate
			}
		}

		return [zlib $mode [lindex $args end]]
	}
}
