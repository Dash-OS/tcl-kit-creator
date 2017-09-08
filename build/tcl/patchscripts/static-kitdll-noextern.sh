#! /bin/bash

if [ "${KITTARGET}" != "kitdll" ]; then
	exit 0
fi

if [ "${KITCREATOR_STATIC_KITDLL}" != '1' ]; then
	exit 0
fi

# For a static KitDLL we are linking directly to the object
# so there is nothing external.
sed 's/define EXTERN .*/define EXTERN/' generic/tcl.h > generic/tcl.h.new
cat generic/tcl.h.new > generic/tcl.h
rm -f generic/tcl.h.new
