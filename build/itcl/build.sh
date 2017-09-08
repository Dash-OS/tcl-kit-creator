#! /usr/bin/env bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

ITCLVERS="3.4.3"
ITCLVERSEXTRA=""
SRC="src/itcl-${ITCLVERS}.tar.gz"
SRCURL="http://sourceforge.net/projects/incrtcl/files/%5BIncr%20Tcl_Tk%5D-source/Itcl%20${ITCLVERS}/itcl${ITCLVERS}${ITCLVERSEXTRA}.tar.gz/download"
SRCHASH='28b55f44a2fd450862a6f12982c00c1d03d767f62a834d83945a616e06068887'
BUILDDIR="$(pwd)/build/itcl${ITCLVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
export ITCLVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR

# Set configure options for this sub-project
LDFLAGS="${LDFLAGS} ${KC_ITCL_LDFLAGS}"
CFLAGS="${CFLAGS} ${KC_ITCL_CFLAGS}"
CPPFLAGS="${CPPFLAGS} ${KC_ITCL_CPPFLAGS}"
LIBS="${LIBS} ${KC_ITCL_LIBS}"
export LDFLAGS CFLAGS CPPFLAGS LIBS

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

# Determine if Itcl is even needed
(
	# Always build if we are being forced to build
	if [ "${KITCREATOR_ITCL3_FORCE}" = '1' ]; then
		exit 0
	fi

	TCL_VERSION="unknown"
	if [ -f "${TCLCONFIGDIR}/tclConfig.sh" ]; then
		source "${TCLCONFIGDIR}/tclConfig.sh"
	fi

	if echo "${TCL_VERSION}" | grep '^8\.[45]$' >/dev/null; then
		# Itcl is required for Tcl 8.4 and Tcl 8.5

		exit 0
	fi

	if [ "${TCL_VERSION}" = "unknown" ]; then
		# If we don't know what version of Tcl we are building, build
		# Itcl just in case.

		exit 0
	fi

	# All other versions do not require Itcl
	echo "Skipping building Itcl, not required for ${TCL_VERSION}"
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

	# Work around bug where Itcl v3.4 picks up wrong platform when cross-compiling
	case "${TCLCONFIGDIR}" in
		*/win)
			TEA_PLATFORM="windows"
			export TEA_PLATFORM
			;;
		*)
			TEA_PLATFORM="unix"
			export TEA_PLATFORM
			;;
	esac
	sed 's@TEA_PLATFORM=@test -z "$TEA_PLATFORM" \&\& &@' configure > configure.new && cat configure.new > configure
	rm -f configure.new

	# Build
	echo "Running: ./configure --enable-shared --disable-symbols --prefix=\"${INSTDIR}\" --exec-prefix=\"${INSTDIR}\" --libdir=\"${INSTDIR}/lib\" --with-tcl=\"${TCLCONFIGDIR}\" ${CONFIGUREEXTRA}"
	./configure --enable-shared --disable-symbols --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --libdir="${INSTDIR}/lib" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

	echo "Running: ${MAKE:-make}"
	${MAKE:-make} || exit 1

	echo "Running: ${MAKE:-make} install"
	${MAKE:-make} install

	mkdir "${OUTDIR}/lib" || exit 1
	cp -r "${INSTDIR}/lib"/itcl* "${OUTDIR}/lib/"

	"${STRIP:-strip}" -g "${OUTDIR}"/lib/itcl*/*.so >/dev/null 2>/dev/null

	exit 0
) || exit 1

exit 0
