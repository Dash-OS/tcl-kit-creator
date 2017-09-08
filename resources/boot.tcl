proc onBoot {} {
  rename onBoot {}
  package require tcl-modules
  # Secretly load Dash functionality should we be outside of the interactive
  # environment.
  if { [info exists ::env(DOS_RUNNER)] || ( [info exists ::tcl_interactive] && ! $::tcl_interactive ) } {
    try {
      package require dos
      if { [info exists ::env(DOS_WATCHDOG)] && [string is true -strict $::env(DOS_WATCHDOG)] } {
        ::startup::start watchdog
        if { [info commands ::watchdog::start] ne {} } {
          ::watchdog::start
        }
      } elseif { [info exists ::env(SERVER_SOFTWARE)] && [string match -nocase websocketd* $::env(SERVER_SOFTWARE)] } {
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
}

onBoot
