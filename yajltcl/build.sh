#! /usr/bin/env bash

# BuildCompatible: KitCreator

version="1.5"
url="https://github.com/flightaware/yajl-tcl/archive/v${version}.tar.gz"
sha256='-'

function buildYAJL() {
	local version url hash
	local archive yajlbuilddir

	version='2.1.0'
	url="http://github.com/lloyd/yajl/tarball/${version}"
	hash='-'

	yajlbuilddir="$(pwd)/lloyd-yajl-66cb08c"
	archive="${pkgdir}/src/yajl-${version}.tar.gz"

	echo " *** Building YAJL v${version}" >&2

	if [ ! -e "${pkgdir}/${archive}" ]; then
		"${_download}" "${url}" "${archive}" "${hash}" || return 1
	fi

	(
		gzip -dc "${archive}" | tar -xf - || exit 1
		cd "${yajlbuilddir}" || exit 1

		if [ "${KC_CROSSCOMPILE}" = '1' ]; then
			case "${KC_CROSSCOMPILE_HOST_OS}" in
				*-mingw32|*-mingw32msvc|*-mingw64)
					cmake_system_name='Windows'
					;;
				*)
					cmake_system_name="$(
						echo "${KC_CROSSCOMPILE_HOST_OS}" | \
						cut -f 3 -d - | \
						sed 's@[0-9\.]*$@@' | \
						awk '{ f = substr($1, 1, 1); r = substr($1, 2); print toupper(f) tolower(r) }' | \
						sed 's@bsd$@BSD@;s@^Aix@AIX@;s@^Hpux@HPUX@'
					)"
					;;
			esac

			cmake_extra=(
				-DCMAKE_SYSTEM_NAME="${cmake_system_name}"
				-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER
				-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY
				-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
				-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY
				-DCMAKE_CROSSCOMPILING=1
			)
		else
			cmake_extra=()
		fi

		if [ -n "${CC}" ]; then
			CC_path="$(echo "${CC}" | cut -f 1 -d ' ')"
			CC_flags="$(echo "${CC}" | cut -f 2- -d ' ')"

			cmake_extra=("${cmake_extra[@]}" -DCMAKE_C_COMPILER="${CC_path}")
			if [ -n "${CC_flags}" ]; then
				cmake_extra=("${cmake_extra[@]}" -DCMAKE_C_FLAGS="${CC_flags}")
			fi
		fi

		if [ -n "${CXX}" ]; then
			CXX_path="$(echo "${CXX}" | cut -f 1 -d ' ')"
			CXX_flags="$(echo "${CXX}" | cut -f 2- -d ' ')"

			cmake_extra=("${cmake_extra[@]}" -DCMAKE_CXX_COMPILER="${CXX_path}")
			if [ -n "${CXX_flags}" ]; then
				cmake_extra=("${cmake_extra[@]}" -DCMAKE_CXX_FLAGS="${CXX_flags}")
			fi
		fi

		cmake \
			-DCMAKE_INSTALL_PREFIX="${yajlbuilddir}/INST" \
			-DBUILD_SHARED_LIBS=OFF \
			-DBUILD_STATIC_LIBS=ON \
			"${cmake_extra[@]}" . || exit 1

		${MAKE:-make} || exit 1

		${MAKE:-make} install || exit 1

		rm -f INST/lib/*.so*
		mv INST/lib/libyajl_s.a INST/lib/libyajl.a || exit 1
	) || return 1

	# Include YAJL's build in our pkg-config path
	PKG_CONFIG_PATH="${yajlbuilddir}/INST/share/pkgconfig"
	YAJL_CFLAGS="-I${yajlbuilddir}/INST/include -I${YAJLBUILDDIR}/INST/include/yajl"
	export PKG_CONFIG_PATH YAJL_CFLAGS
}

function preconfigure() {
	# Build YAJL
	buildYAJL || return 1

	# YAJLTCL releases are incomplete -- they lack a configure script
	autoconf || exit 1
}

function postinstall() {
	local file dir

	find "${installdir}" -type f -name '*.a' | head -n 1 | sed 's@/[^/]*$@@' | while IFS='' read -r dir; do
		find "${workdir}" -type f -name 'libyajl.a' | while IFS='' read -r file; do
			cp "${file}" "${dir}/zz-$(basename "${file}")" || return 1
		done
	done
}
