# Anything added will be obsfucated.  Once building the kit this way
# (cvfs type required), you can try finding the following in
# the executable:
# package require d
# A daemon helper for Dash OS that provides masking and obsfucation of key
# commands and data within the dashsh itself.
if {
  [info exists ::env(DOS_RUNNER)]
  || (
    [info exists ::tcl_interactive]
    && [string is false -strict $::tcl_interactive]
  )
} {
  package require fileutil

  if { ! [info exists ::env(ENABLE_LOG)] } {
    set ::env(ENABLE_LOG) 0
  }

  if { [info exists ::env(DOS_BIN)] } {
    set ::env(PATH) "${::env(DOS_BIN)}:$::env(PATH)"
  }

  if { ! [info exists ::env(DOS_PATH)] } {
    set ::env(DOS_PATH) [file join / remote Store Common Dash]
  }

  namespace eval ::startup {}

  namespace eval ::config {
    variable oshash eebg42at4bf1gtn2aeba1kaa4af2gdw2
    variable hash   aebg32at4bf1gtn2aeba1kaa4af1gdw1
  }

  namespace eval ::config::dirs {
    variable tmp        [file join [::fileutil::tempdir] dashos]
    variable app        [file dirname [info script]]
    variable dash       $::env(DOS_PATH)
    variable os         [file join $dash .os]
    variable packages   [file join $os packages]
    variable vfs        [file join $dash vfs os]
    variable vfs_shared [file join $dash vfs shared]
  }

  namespace eval ::config::files {
    variable shared_index  [file join $::config::dirs::vfs_shared index.tcl]
    variable index      [file join $::config::dirs::os scripts sa]
    variable lib        [file join $::config::dirs::os lib dashos.so]
    variable shared     [file join $::config::dirs::os lib dashos_shared.so]
    variable installing [file join $::config::dirs::tmp .installing]
    variable installed  [file join $::config::dirs::tmp .installcomplete]
    variable log        [file join $::config::dirs::tmp log.txt]
    variable sdk        [file join $::config::dirs::vfs sdk.tcl]
    variable sdk_ui     [file join $::config::dirs::vfs sdk_ui.tcl]
    variable ospid      {}
  }

  if { [info exists ::env(DOS_PID_FILE)] } {
    set ::config::files::ospid $::env(DOS_PID_FILE)
  }

  proc EXIT {} {
    if {
         [info exists ::config::files::ospid]
      && [file exists $::config::files::ospid]
    } {
      file delete -force -- $::config::files::ospid
    }
    exit 0
  }

  if { [info commands ::startup::mountosvfs] eq {} } {
    proc ::startup::mountosvfs {} {
      if { [file isfile $::config::files::sdk] && [file isfile $::config::files::shared_index] } { return 1 }
      if { [file isfile $::config::files::shared] } {
        load $::config::files::shared Cvfs_data_${::config::hash}
        ::vfs::cvfs::Mount $::config::hash $::config::dirs::vfs_shared
        if { $::config::dirs::vfs_shared ni $::auto_path } {
          lappend ::auto_path $::config::dirs::vfs_shared
        }
      }
      if { [file isfile $::config::files::lib] } {
        load $::config::files::lib Cvfs_data_${::config::oshash}
        ::vfs::cvfs::Mount $::config::oshash $::config::dirs::vfs
        if { $::config::dirs::vfs ni $::auto_path } {
          lappend ::auto_path $::config::dirs::vfs
        }
      }
      if { [file isfile $::config::files::sdk] && [file isfile $::config::files::shared_index] } {
        return 1
      } else {
        return 0
      }
    }
  }

  # Create the pid file and add our process id for the init.d script to know
  # that we successfully ran.
  proc ::startup::start { { what {} } } {
    try {
      switch -- $what {
        watchdog {
          if { $::config::files::ospid ne {} } {
            if { [file isfile $::config::files::ospid ] } { file delete -force -- $::config::files::ospid }
            ::fileutil::writeFile $::config::files::ospid [pid]
          }
        }
        websocketd {}
      }
      if { [ ::startup::mountosvfs ] } {
        uplevel #0 [list source $::config::files::shared_index]
        uplevel #0 [list source $::config::files::sdk]
        if { [namespace exists ::startup] } {
          namespace delete ::startup
        }
      } elseif { [namespace exists ::startup] } {
        set ::dos_success 0
        namespace delete ::startup
      }
    } on error {result options} {
      puts stderr "ERROR DURING INITIALIZATION"
      puts stderr $result
      puts stderr $options
    }
  }

  try {
		if {
      [info exists ::env(DOS_WATCHDOG)]
      && [string is true -strict $::env(DOS_WATCHDOG)]
    } {
			::startup::start watchdog
			if { [info commands ::watchdog::start] ne {} } {
				::watchdog::start
			}
		} elseif {
         [info exists ::env(SERVER_SOFTWARE)]
      && [string match -nocase websocketd* $::env(SERVER_SOFTWARE)]
    } {
			::startup::start websocketd
			if { [info commands ::watchdog::websocketd] ne {} } {
				::watchdog::websocketd
			}
		} elseif { [info commands ::startup::start] ne {} } {
			::startup::start
		}
	} on error {result options} {
		# Mainly provided as a response to a websocketd connection, but also printed
		# for other startups
		puts [format {{
			"result": "error",
			"errorMessage": "%s"
		}} [string map {{"} {\"}} $result]]
	}
}
