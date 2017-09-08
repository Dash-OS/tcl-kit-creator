#! /usr/bin/env bash

# BuildCompatible: KitCreator

pkg='dbus'
version="2.0"
url="http://sourceforge.net/projects/dbus-tcl/files/dbus/${version}/dbus-${version}.tar.gz"
sha256='428b4045d395b0d26255730ce7c0d14850e45abb3c7cc6d9d48c1d2b723bb16a'

function postinstall() {
	local archive

	archive="$(find "${installdir}" -name '*.a' | head -n 1)"
	if [ -n "${archive}" ]; then
		echo '-ldbus-1' > "${archive}.linkadd"
	fi
}
