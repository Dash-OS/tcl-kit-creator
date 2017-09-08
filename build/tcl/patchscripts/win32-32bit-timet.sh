#! /usr/bin/env bash

# Do not run on Win32
if echo '_WIN64' | ${CC:-cc} -E - | grep '^_WIN64$' >/dev/null; then
	(
		echo '#ifndef _USE_32BIT_TIME_T'
		echo '#define _USE_32BIT_TIME_T 1'
		echo '#endif'
		cat generic/tcl.h
	) > generic/tcl.h.new
	cat generic/tcl.h.new > generic/tcl.h
fi

exit 0
