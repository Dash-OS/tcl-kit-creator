#! /usr/bin/env bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

THREADVERS="2.7.2"
SRC="src/thread-${THREADVERS}.tar.gz"
SRCURL="http://sourceforge.net/projects/tcl/files/Thread%20Extension/${THREADVERS}/thread${THREADVERS}.tar.gz/download"
SRCHASH='-'
BUILDDIR="$(pwd)/build/thread${THREADVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
export THREADVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR

# Set configure options for this sub-project
LDFLAGS="${LDFLAGS} ${KC_THREAD_LDFLAGS}"
CFLAGS="${CFLAGS} ${KC_THREAD_CFLAGS}"
CPPFLAGS="${CPPFLAGS} ${KC_THREAD_CPPFLAGS}"
LIBS="${LIBS} ${KC_THREAD_LIBS}"
export LDFLAGS CFLAGS CPPFLAGS LIBS

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

# Determine if Threads is even needed
(
	TCL_VERSION="unknown"
	if [ -f "${TCLCONFIGDIR}/tclConfig.sh" ]; then
		source "${TCLCONFIGDIR}/tclConfig.sh"
	fi

	if echo "${TCL_VERSION}" | grep '^8\.[45]$' >/dev/null; then
		# Threads may be required for Tcl 8.4 and Tcl 8.5

                exit 0
        fi

	if [ "${TCL_VERSION}" = "unknown" ]; then
		# If we dont know what version of Tcl we are building, build
		# Threads just in case.

		exit 0
	fi

	# All other versions do not require Threads
	echo "Skipping building Threads, not required for ${TCL_VERSION}"
	exit 1
) || exit 0

if [ ! -f "${SRC}" ]; then
	mkdir 'src' >/dev/null 2>/dev/null

	if [ ! -d 'buildsrc' ]; then
		download "${SRCURL}" "${SRC}" "${SRCHASH}" || exit 1
	fi
fi

(
	cd 'build' || exit 1

	if [ ! -d '../buildsrc' ]; then
		gzip -dc "../${SRC}" | tar -xf -
	else
		cp -rp ../buildsrc/* './'
	fi

	cd "${BUILDDIR}" || exit 1


	# Try to build as a shared object if requested
	if [ "${STATICTHREAD}" = "0" ]; then
		tryopts="--enable-shared --disable-shared"
	elif [ "${STATICTHREAD}" = "1" ]; then
		tryopts="--disable-shared"
	else
		tryopts="--enable-shared"
	fi

	SAVE_CFLAGS="${CFLAGS}"
	for tryopt in $tryopts __fail__; do
		# Clean up, if needed
		make distclean >/dev/null 2>/dev/null
		rm -rf "${INSTDIR}"
		mkdir "${INSTDIR}"

		if [ "${tryopt}" = "__fail__" ]; then
			exit 1
		fi

		if [ "${tryopt}" == "--enable-shared" ]; then
			isshared="1"
		else
			isshared="0"
		fi

		# If build a static TLS for KitDLL, ensure that we use PIC
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
			echo "Running: ./configure $tryopt --disable-symbols --prefix=\"${INSTDIR}\" --exec-prefix=\"${INSTDIR}\" --libdir=\"${INSTDIR}/lib\" --with-tcl=\"${TCLCONFIGDIR}\" ${CONFIGUREEXTRA}"
			./configure $tryopt --disable-symbols --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --libdir="${INSTDIR}/lib" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

			echo "Running: ${MAKE:-make}"
			${MAKE:-make} || exit 1

			echo "Running: ${MAKE:-make} install"
			${MAKE:-make} install
		) || continue

		break
	done

	mkdir "${OUTDIR}/lib" || exit 1
	cp -r "${INSTDIR}/lib"/thread*/ "${OUTDIR}/lib/"
	rm -f "${OUTDIR}"/lib/thread*/*.a

	if [ "${isshared}" = '0' ]; then
		cat << _EOF_ > "${OUTDIR}/lib/thread${THREADVERS}/pkgIndex.tcl"
package ifneeded Thread ${THREADVERS} [list load "" Thread]
package ifneeded Ttrace ${THREADVERS} [list source [file join $dir ttrace.tcl]]
_EOF_
	fi

	"${STRIP:-strip}" -g "${OUTDIR}"/lib/thread*/*.so >/dev/null 2>/dev/null

	exit 0
) || exit 1

exit 0
