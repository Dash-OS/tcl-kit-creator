#! /usr/bin/env bash

if [ "${KITTARGET}" != "kitdll" ]; then
	exit 0
fi

## DllMain is needed when building KitDLL
for filetopatch in win/tclWin32Dll.c win/tclWinInit.c; do
	echo "Undefining STATIC_BUILD in \"${filetopatch}\""

	sed 's@STATIC_BUILD@NEVER_STATIC_BUILD@g' "${filetopatch}" > "${filetopatch}.new" && cat "${filetopatch}.new" > "${filetopatch}"
	rm -f "${filetopatch}.new"
done
