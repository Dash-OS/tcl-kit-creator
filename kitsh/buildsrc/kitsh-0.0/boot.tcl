proc tclInit {} {
	rename tclInit {}

	global auto_path tcl_library tcl_libPath
	global tcl_version tcl_rcFileName
  
	set mountpoint [subst "$::TCLKIT_MOUNTPOINT_VAR"]

	# Resolve symlinks
	set mountpoint [file dirname [file normalize [file join $mountpoint __dummy__]]]

	set tcl_library [file join $mountpoint lib tcl$tcl_version]
	set tcl_libPath [list $tcl_library [file join $mountpoint lib]]

	# the following code only gets executed once on startup
	if {[info exists ::TCLKIT_INITVFS]} {
		# lookup and emulate "source" of lib/vfs/{vfs*.tcl,mk4vfs.tcl}
		switch -- $::tclKitStorage {
			"mk4" {
				# must use raw MetaKit calls because VFS is not yet in place
				set d [mk::select exe.dirs parent 0 name lib]
				set d [mk::select exe.dirs parent $d name vfs]
    
				foreach x {vfsUtils vfslib mk4vfs} {
					set n [mk::select exe.dirs!$d.files name $x.tcl]
					set s [mk::get exe.dirs!$d.files!$n contents]
					catch {set s [zlib decompress $s]}
					uplevel #0 $s
				}

				# use on-the-fly decompression, if mk4vfs understands that
				set mk4vfs::zstreamed 1

				# Set VFS handler name
				set vfsHandler [list ::vfs::mk4::handler exe]
			}
			"zip" {
				set prefix "lib/vfs"
				foreach file [list vfsUtils vfslib] {
					set fullfile "${prefix}/${file}.tcl"

					::zip::stat $::tclKitStorage_fd $fullfile finfo
					seek $::tclKitStorage_fd $finfo(ino)
					zip::Data $::tclKitStorage_fd sb s

					switch -- $file {
						"vfsUtils" {
							# Preserve our working "::vfs::zip" implementation
							# so we can replace it after the stub is replaced
							# from vfsUtils
							# The correct implementation will be provided by vfslib, 
							# but only if we can read it
							rename ::vfs::zip ::vfs::zip_impl
						}
					}

					uplevel #0 $s

					switch -- $file {
						"vfsUtils" {
							# Restore preserved "::vfs:zip" implementation
							rename ::vfs::zip {}
							rename ::vfs::zip_impl ::vfs::zip
						}
					}
				}

				seek $::tclKitStorage_fd 0
				set vfsHandler [list ::vfs::zip::handler $::tclKitStorage_fd]
				unset ::tclKitStorage_fd
			}
			"cvfs" {
				set vfsHandler [list ::vfs::cvfs::vfshandler tcl]

				# Load these, the original Tclkit does so it should be safe.
				foreach vfsfile [list vfsUtils vfslib] {
					unset -nocomplain s

					catch {
						set s [::vfs::cvfs::data::getData tcl "lib/vfs/${vfsfile}.tcl"]
					}

					if {![info exists s]} {
						continue
					}

					uplevel #0 $s
				}
			}
		}

		# mount the executable, i.e. make all runtime files available
		vfs::filesystem mount $mountpoint $vfsHandler

		# alter path to find encodings
		if {[info tclversion] eq "8.4"} {
			load {} pwb
			librarypath [info library]
		} else {
			encoding dirs [list [file join [info library] encoding]] ;# TIP 258
		}

		# fix system encoding, if it wasn't properly set up (200207.004 bug)
		if {[encoding system] eq "identity"} {
			if {[info exists ::tclkit_system_encoding] && $::tclkit_system_encoding != ""} {
				catch {
					encoding system $::tclkit_system_encoding
				}
			}
		}

		# If we've still not been able to set the encoding, revert to Tclkit defaults
		if {[encoding system] eq "identity"} {
			catch {
				switch $::tcl_platform(platform) {
					windows		{ encoding system cp1252 }
					macintosh	{ encoding system macRoman }
				        default		{ encoding system iso8859-1 }
				}
			}
		}

		# Re-evaluate mountpoint with correct encoding set
		set mountpoint [subst "$::TCLKIT_MOUNTPOINT_VAR"]

		# now remount the executable with the correct encoding
		vfs::filesystem unmount [lindex [::vfs::filesystem info] 0]

		# Resolve symlinks
		set mountpoint [file dirname [file normalize [file join $mountpoint __dummy__]]]

		set tcl_library [file join $mountpoint lib tcl$tcl_version]
		set tcl_libPath [list $tcl_library [file join $mountpoint lib]]

		vfs::filesystem mount $mountpoint $vfsHandler

		# This loads everything needed for "clock scan" to work
		# "clock scan" is used within "vfs::zip", which may be
		# loaded before this is run causing the root VFS to break
		catch { clock scan }
	}
  
	# load config settings file if present
	namespace eval ::vfs { variable tclkit_version 1 }
	catch { uplevel #0 [list source [file join $mountpoint config.tcl]] }

	# Set-up starkit::tclkitroot
	namespace eval ::starkit { variable tclkitroot }
	set ::starkit::tclkitroot $mountpoint

	# Perform expected initialization
	uplevel #0 [list source [file join $tcl_library init.tcl]]
  
	# reset auto_path, so that init.tcl's search outside of tclkit is cancelled
	set auto_path $tcl_libPath

	# Update Tcl Module system as well
	if {[info command ::tcl::tm::path] ne ""} {
		tcl::tm::path remove {*}[tcl::tm::path list]
		tcl::tm::roots [file join $::starkit::tclkitroot lib]
	}

	if {$::TCLKIT_TYPE == "kitdll"} {
		# Set a maximum seek to avoid reading the entire file looking for a
		# zip header
		catch { 
			package require vfs::zip
			set ::zip::max_header_seek 8192
		}

		# Now that the initialization is complete, mount the user VFS if needed
		## Mount the VFS from the Shared Object
		if {[info exists ::TCLKIT_INITVFS] && [info exists ::tclKitFilename]} {
			if {![catch {
				vfs::zip::Mount $::tclKitFilename "/.KITDLL_USER"
			}]} {
				if {[file exists "/.KITDLL_USER"]} {
					lappend auto_path [file normalize "/.KITDLL_USER/lib"]
				}
			}
		}


		## Mount the VFS from executable
		if {[info exists ::TCLKIT_INITVFS]} {
			if {![catch {
				vfs::zip::Mount [info nameofexecutable] "/.KITDLL_APP"
			}]} {
				if {[file exists "/.KITDLL_APP"]} {
					lappend auto_path [file normalize "/.KITDLL_APP/lib"]
				}
			}
		}
	}

	# Clean up
	unset -nocomplain ::zip::max_header_seek
	unset -nocomplain ::TCLKIT_TYPE ::TCLKIT_INITVFS
	unset -nocomplain ::TCLKIT_MOUNTPOINT ::TCLKIT_VFSSOURCE ::TCLKIT_MOUNTPOINT_VAR ::TCLKIT_VFSSOURCE_VAR
	unset -nocomplain ::tclKitStorage ::tclKitStorage_fd ::tclKitFilename
	unset -nocomplain ::tclkit_system_encoding
}
