#! /bin/bash

if [ -z "${KC_TCL_UTF_MAX}" ]; then
	exit 0
fi

sed 's@^# *define TCL_UTF_MAX.*$@#define TCL_UTF_MAX '"${KC_TCL_UTF_MAX}"'@' generic/tcl.h > generic/tcl.h.new
cat generic/tcl.h.new > generic/tcl.h
rm -f generic/tcl.h.new

exit 0
