#! /usr/bin/env bash

# BuildCompatible: KitCreator

version="1.2.8"
url="http://sourceforge.net/projects/libpng/files/zlib/${version}/zlib-${version}.tar.gz"
sha256='36658cb768a54c1d4dec43c3116c27ed893e88b02ecfcb44f2166f9c0b7f2a0d'

function configure() {
	case "$(uname -s 2>/dev/null | dd conv=lcase 2>/dev/null)" in
		mingw*)
			cp win32/Makefile.gcc Makefile
			make_extra=(BINARY_PATH="${installdir}/bin" INCLUDE_PATH="${installdir}/include" LIBRARY_PATH="${installdir}/lib")
			;;
		*)
			if [ "${KITTARGET}" = "kitdll" ]; then
				CFLAGS="${CFLAGS} -fPIC"
				export CFLAGS
			fi

			./configure --prefix="${installdir}" --libdir="${installdir}/lib" --static
			;;
	esac
}

function createruntime() {
	:
}
