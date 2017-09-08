#! /usr/bin/env bash

if [ ! -f 'build.sh' ]; then
    echo 'ERROR: This script must be run from the directory it is in' >&2
    
    exit 1
fi
if [ -z "${TCLVERS}" ]; then
    echo 'ERROR: The TCLVERS environment variable is not set' >&2
    
    exit 1
fi


use_git='0'

if echo "${TCLVERS}" | grep '^fossil_' >/dev/null; then
    use_git='1'
    GITTAG='master'
    NSFVERS="${GITTAG}"
    NSFVERSEXTRA=""
    SRC="src/nsf${GITTAG}.zip"
    SRCURL="http://fisheye.openacs.org/browse/~tarball=zip,br=${GITTAG}/nsf/nsf.zip"
    SRCHASH='-'
else
    NSFVERS="2.1.0"
    NSFVERSEXTRA=""
    SRC="src/nsf${NSFVERS}.tar.gz"
    SRCURL="http://sourceforge.net/projects/next-scripting/files/${NSFVERS}/nsf${NSFVERS}.tar.gz/download"
    SRCHASH='00ed655eac33a85128094f9049166eea37569b68'
fi

BUILDDIR="$(pwd)/build/nsf${NSFVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
export NSFVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR

# Set configure options for this sub-project
LDFLAGS="${LDFLAGS} ${KC_NSF_LDFLAGS}"
CFLAGS="${CFLAGS} ${KC_NSF_CFLAGS}"
CPPFLAGS="${CPPFLAGS} ${KC_NSF_CPPFLAGS}"
LIBS="${LIBS} ${KC_NSF_LIBS}"
export LDFLAGS CFLAGS CPPFLAGS LIBS

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

if [ ! -f "${SRC}" ]; then
    mkdir 'src' >/dev/null 2>/dev/null
    
    if [ ! -d 'buildsrc' ]; then
	download "${SRCURL}" "${SRC}" "${SRCHASH}" || exit 1
    fi
fi

(
    cd 'build' || exit 1
    
    if [ ! -d '../buildsrc' ]; then
	if [ "${use_git}" = "1" ]; then
	    unzip "../${SRC}" -d nsf${NSFVERS}
	else
	    gzip -dc "../${SRC}" | tar -xf -
	fi
    else    
	cp -rp ../buildsrc/* './'
    fi
    
    cd "${BUILDDIR}" || exit 1

    if [ "${use_git}" = "1" ]; then
	## the GIT zip tarball does not preserve file permissions (configure)
	rm -rf configure
	autoconf || exit 1
    fi


    # There's a STATIC<packageInAllUpperCase>=-1,0,1
    # ... where -1 means no (i.e., shared),
    # ... 0 means try not to (try shared first, if that
    # 	  doesn't work do static),
    # ... and 1 means try to (try only static)
    
    if [ "${STATICNSF}" = "0" ]; then
	tryopts="--enable-shared --disable-shared"
    elif [ "${STATICNSF}" = "1" ]; then
	tryopts="--disable-shared"
    else
	# -1
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
	
	# If build a static NSF for KitDLL, ensure that we use PIC
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

	# Fix mkIndex.tcl for TCLSH_NATIVE being 8.4 (till next NSF release)
	cat library/lib/mkIndex.tcl > library/lib/mkIndex.tcl.orig
	cat << _EOF_ > library/lib/mkIndex.tcl
if {[info commands ::tcl::tm::roots] eq ""} {
	namespace eval ::tcl::tm { proc roots args {;}} 
}
source [file join [file dirname [info script]] mkIndex.tcl.orig]
_EOF_
	(
	    # Build
	    echo "Running: ./configure $tryopt --disable-symbols --prefix=\"${INSTDIR}\" --exec-prefix=\"${INSTDIR}\" --libdir=\"${INSTDIR}/lib\" --with-tcl=\"${TCLCONFIGDIR}\" ${CONFIGUREEXTRA}"
	    ./configure $tryopt --disable-symbols --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --libdir="${INSTDIR}/lib" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

	    echo "Running: ${MAKE:-make} TCLSH=${TCLSH_NATIVE}"
	    ${MAKE:-make} TCLSH=${TCLSH_NATIVE} || exit 1

	    echo "Running: ${MAKE:-make} install TCLSH=${TCLSH_NATIVE}"
	    ${MAKE:-make} install TCLSH=${TCLSH_NATIVE} || exit 1
	    
	) || continue
	
	break
    done

    if [ "${use_git}" = "1" ]; then
	NSFVERS="$(source nsfConfig.sh && echo ${NSF_PATCH_LEVEL})"
    fi
    
    mkdir "${OUTDIR}/lib" || exit 1
    cp -r "${INSTDIR}/lib"/nsf*/serialize "${OUTDIR}/lib/nsf${NSFVERS}-serialize"
    cp -r "${INSTDIR}/lib"/nsf*/lib "${OUTDIR}/lib/nsf${NSFVERS}-lib"
    cp -r "${INSTDIR}/lib"/nsf*/nx "${OUTDIR}/lib/nsf${NSFVERS}-nx"
    cp -r "${INSTDIR}/lib"/nsf*/xotcl "${OUTDIR}/lib/nsf${NSFVERS}-xotcl"
    
    mkdir "${OUTDIR}/lib/nsf${NSFVERS}" || exit 1
    
    if [ "${isshared}" = '0' ]; then
	cat << _EOF_ > "${OUTDIR}/lib/nsf${NSFVERS}/pkgIndex.tcl"
package ifneeded nsf ${NSFVERS} "[list load "" nsf]; package provide nsf ${NSFVERS}"
_EOF_
    else
	cp -r "${INSTDIR}/lib"/nsf*/*nsf*.* "${OUTDIR}/lib/nsf${NSFVERS}/"
	cp -r "${INSTDIR}/lib"/nsf*/pkgIndex.tcl "${OUTDIR}/lib/nsf${NSFVERS}/"
    fi
    
    rm -f "${OUTDIR}"/lib/nsf*/*.a
    
    "${STRIP:-strip}" -g "${OUTDIR}"/lib/nsf*/*.so >/dev/null 2>/dev/null
    
    exit 0
) || exit 1
exit 0
