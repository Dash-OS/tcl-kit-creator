#! /usr/bin/env bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

YAJLTCLVERS="1.6.2"
YAJLVERS='2.1.0'
SRC="src/yajltcl-${YAJLTCLVERS}.tar.gz"
YAJLSRC="src/yajl-${YAJLVERS}.tar.gz"
SRCURL="https://github.com/flightaware/yajl-tcl/archive/v${YAJLTCLVERS}.tar.gz"
SRCHASH='-'
YAJLSRCURL="http://github.com/lloyd/yajl/tarball/${YAJLVERS}"
YAJLSRCHASH='-'
BUILDDIR="$(pwd)/build/yajl-tcl-${YAJLTCLVERS}"
YAJLBUILDDIR="$(pwd)/build/lloyd-yajl-66cb08c"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
PATCHDIR="$(pwd)/patches"

export YAJLTCLVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR PATCHDIR

# Set configure options for this sub-project
LDFLAGS="${LDFLAGS} ${KC_YAJLTCL_LDFLAGS}"
CFLAGS="${CFLAGS} ${KC_YAJLTCL_CFLAGS}"
CPPFLAGS="${CPPFLAGS} ${KC_YAJLTCL_CPPFLAGS}"
LIBS="${LIBS} ${KC_YAJLTCL_LIBS}"
export LDFLAGS CFLAGS CPPFLAGS LIBS

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

if [ ! -d 'buildsrc' ]; then
	mkdir 'src' >/dev/null 2>/dev/null

	if [ ! -f "${SRC}" ]; then
		download "${SRCURL}" "${SRC}" "${SRCHASH}" || exit 1
	fi

	if [ ! -f "${YAJLSRC}" ]; then
		download "${YAJLSRCURL}" "${YAJLSRC}" "${YAJLSRCHASH}" || exit 1
	fi
fi

(
	cd 'build' || exit 1

	if [ ! -d '../buildsrc' ]; then
		gzip -dc "../${SRC}" | tar -xf -
		gzip -dc "../${YAJLSRC}" | tar -xf -
	else
		cp -rp ../buildsrc/* './'
	fi

	# Build YAJL
	(
		cd "${YAJLBUILDDIR}" || exit 1
		./configure -p "$(pwd)/INST" || exit 1
		make install || exit 1
		#rm -f INST/lib/*.so*
		mv INST/lib/libyajl_s.a INST/lib/libyajl.a || exit 1
	) || exit 1

	# Include YAJL's build in our pkg-config path
	PKG_CONFIG_PATH="${YAJLBUILDDIR}/INST/share/pkgconfig"
	YAJL_CFLAGS="-I${YAJLBUILDDIR}/INST/include -I${YAJLBUILDDIR}/INST/include/yajl"
	export PKG_CONFIG_PATH YAJL_CFLAGS

	# Build YAJL-TCL
	cd "${BUILDDIR}" || exit 1

	# YAJLTCL releases are incomplete -- they lack a configure script
	autoconf || exit 1

	# Try to build as a shared object if requested
	if [ "${STATICYAJLTCL}" = "0" ]; then
		tryopts="--enable-shared --disable-shared"
	elif [ "${STATICYAJLTCL}" = "-1" ]; then
		tryopts="--enable-shared"
	else
		tryopts="--disable-shared"
	fi

	SAVE_CFLAGS="${CFLAGS}"
	for tryopt in $tryopts __fail__; do
		if [ "${tryopt}" = "__fail__" ]; then
			exit 1
		fi
		# Clean up, if needed
		make distclean >/dev/null 2>/dev/null
		rm -rf "${INSTDIR}"
		mkdir "${INSTDIR}"

		if [ "${tryopt}" == "--enable-shared" ]; then
			isshared="1"
		else
			isshared="0"
		fi

		# If build a static YAJLTCL for KitDLL, ensure that we use PIC
		# so that it can be linked into the shared object
		if [ "${isshared}" = "0" -a "${KITTARGET}" = "kitdll" ]; then
			CFLAGS="${SAVE_CFLAGS} -fPIC"
		else
			CFLAGS="${SAVE_CFLAGS}"
		fi
		export CFLAGS

		if [ "${isshared}" = '0' ]; then
			sed 's@USE_TCL_STUBS@XXX_TCL_STUBS@g' configure > configure.new
		else
			sed 's@XXX_TCL_STUBS@USE_TCL_STUBS@g' configure > configure.new
		fi
		cat configure.new > configure
		rm -f configure.new

		(
			echo "Running: ./configure $tryopt --prefix=\"${INSTDIR}\" --exec-prefix=\"${INSTDIR}\" --libdir=\"${INSTDIR}/lib\" --with-tcl=\"${TCLCONFIGDIR}\" ${CONFIGUREEXTRA}"
			./configure $tryopt --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --libdir="${INSTDIR}/lib" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

			echo "Running: ${MAKE:-make} tcllibdir=\"${INSTDIR}/lib\""
			${MAKE:-make} tcllibdir="${INSTDIR}/lib" || exit 1

			echo "Running: ${MAKE:-make} tcllibdir=\"${INSTDIR}/lib\" install"
			${MAKE:-make} tcllibdir="${INSTDIR}/lib" install || exit 1
		) || continue

		if [ "${isshared}" = '0' ]; then
			# Copy static libyajl to INSTDIR
			mkdir -p "${INSTDIR}/lib/deps"
			cp "${YAJLBUILDDIR}/INST/lib/libyajl.a" "${INSTDIR}/lib/zz-libyajl.a" || exit 1
		fi

		break
	done

	# Create pkgIndex if needed
	if [ ! -e "${INSTDIR}/lib/yajltcl${YAJLTCLVERS}/pkgIndex.tcl" ]; then
		cat << _EOF_ > "${INSTDIR}/lib/yajltcl${YAJLTCLVERS}/pkgIndex.tcl"
package ifneeded yajltcl ${YAJLTCLVERS} \
    "[list load {} yajltcl]; \
    [list source [file join \$dir yajl.tcl]]"
_EOF_
	fi

	# Install files needed by installation
	cp -r "${INSTDIR}/lib" "${OUTDIR}" || exit 1
	find "${OUTDIR}" -name '*.a' -type f | xargs -n 1 rm -f --

	exit 0
) || exit 1

exit 0
