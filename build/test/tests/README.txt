Tests for KitCreator
--------------------

Each script that matches "*.tcl" is run in a brand new interpreter,
invoked as:
	tclkit <scriptname> <tclkitfilename> <kit-build-info> <tcl-version>

If a cooresponding ".sh" script is found, it is sourced into the shell
prior to executing the build Tclkit.
