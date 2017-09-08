#! /usr/bin/env bash

# BuildCompatible: KitCreator

version="20080503"
url="http://sourceforge.net/projects/tclvfs/files/tclvfs/tclvfs-${version}/tclvfs-${version}.tar.gz"
sha256='0d90362078c8f59347b14be377e9306336b6d25d147397f845e705a6fa1d38f2'

function init_kitcreator() {
	pkg_always_static='1'
}

function preconfigure() {
	local buildtype

	cp generic/vfs.c .

	# If we are building for Win32, we need to define TEA_PLATFORM so that
	# the right private directory is found
	buildtype="$(basename "${TCLCONFIGDIR}")"
	if [ "${buildtype}" = "win" ]; then
		TEA_PLATFORM="windows"
		export TEA_PLATFORM

		CFLAGS="${CFLAGS} -I${TCLCONFIGDIR}"
		export CFLAGS
	fi
}
