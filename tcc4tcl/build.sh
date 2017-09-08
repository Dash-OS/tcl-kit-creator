#! /usr/bin/env bash

# BuildCompatible: KitCreator

version="0.28"
url="http://rkeene.org/devel/tcc4tcl/tcc4tcl-${version}.tar.gz"
sha256='7062bd924b91d2ce8efc5d1983f8bd900514b7a674c9b567f564ee977ef3512e'

function preconfigure() {
	if echo " ${CONFIGUREEXTRA} " | grep ' --disable-load ' >/dev/null; then
		configure_extra=("--with-dlopen")
	else
		configure_extra=("--without-dlopen")
	fi
}

function postinstall() {
	echo "/libtcc1\.a" > "${installdir}/kitcreator-nolibs"
}

function createruntime() {
	local filename

	# Create VFS-insert
	mkdir -p "${runtimedir}" || return 1
	cp -r "${installdir}/lib" "${runtimedir}" || return 1

	find "${runtimedir}" -name '*.a' -type f | grep -v '/libtcc1\.a$' | while IFS='' read -r filename; do
		rm -f "${filename}"
	done
}
