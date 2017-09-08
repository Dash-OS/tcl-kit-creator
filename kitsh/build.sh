#! /usr/bin/env bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

KITSHVERS="0.0"
BUILDDIR="$(pwd)/build/kitsh-${KITSHVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
OTHERPKGSDIR="$(pwd)/../"
export KITSHVERS BUILDDIR OUTDIR INSTDIR OTHERPKGSDIR

# Set configure options for this sub-project
LDFLAGS_ADD="${KC_KITSH_LDFLAGS_ADD}"
LDFLAGS="${LDFLAGS} ${KC_KITSH_LDFLAGS}"
CFLAGS="${CFLAGS} ${KC_KITSH_CFLAGS}"
CPPFLAGS="${CPPFLAGS} ${KC_KITSH_CPPFLAGS}"
LIBS="${LIBS} ${KC_KITSH_LIBS}"
export LDFLAGS_ADD LDFLAGS CFLAGS CPPFLAGS LIBS

if [ -z "${ENABLECOMPRESSION}" ]; then
	ENABLECOMPRESSION="1"
fi
export ENABLECOMPRESSION

rm -rf 'build' 'out' 'inst'
mkdir 'out' 'inst' || exit 1


(
	cp -rp 'buildsrc' 'build'
	cd "${BUILDDIR}" || exit 1

	# Fix up archives that Tcl gets wrong
	for archive in ../../../tcl/inst/lib/dde*/tcldde*.a ../../../tcl/inst/lib/reg*/tclreg*.a; do
		if [ ! -f "${archive}" ]; then
			continue
		fi

		rm -rf __TEMP__
		(
			mkdir __TEMP__ || exit 1
			cd __TEMP__

			## Patch archive name
			archive="../${archive}"

			"${AR:-ar}" x "${archive}" || exit 1

			rm -f "${archive}"

			"${AR:-ar}" cr "${archive}" *.o || exit 1
			"${RANLIB:-ranlib}" "${archive}" || true
		)
	done

	# Cleanup, just incase the incoming directory was not pre-cleaned
	${MAKE:-make} distclean >/dev/null 2>/dev/null
	rm -rf 'starpack.vfs'

	# Create VFS directory
	mkdir "starpack.vfs"
	mkdir "starpack.vfs/lib"

	## Install "boot.tcl"
	cp 'boot.tcl' 'starpack.vfs/'

	## Install "tclkit.ico"
	cp 'tclkit.ico' 'starpack.vfs/'

	## Copy in all built directories
	cp -r "${OTHERPKGSDIR}"/*/out/* 'starpack.vfs/'

	## Rename the "vfs" package directory to what "boot.tcl" expects
	mv 'starpack.vfs/lib'/vfs* 'starpack.vfs/lib/vfs'

	# Figure out if zlib compiled (if not, the system zlib will be used and we
	# will need to have that present)
	ZLIBDIR="$(cd "${OTHERPKGSDIR}/zlib/inst" 2>/dev/null && pwd)"
	export ZLIBDIR
	if [ -z "${ZLIBDIR}" -o ! -f "${ZLIBDIR}/lib/libz.a" ]; then
		unset ZLIBDIR
	fi

	# Copy user specified kit.rc and tclkit.ico in to build directory, if found
	cp "${KITCREATOR_ICON}" "${BUILDDIR}/tclkit.ico"
	cp "${KITCREATOR_RC}" "${BUILDDIR}/kit.rc"

	# Include extra objects as required
	## Initialize list of extra objects
	EXTRA_OBJS=""
	export EXTRA_OBJS

	## Tk Resources (needed for Win32 support) -- remove kit-found resources to prevent the symbols from being in conflict
	TKDIR="$(cd "${OTHERPKGSDIR}/tk/inst" 2>/dev/null && pwd)"
	if [ -n "${TKDIR}" ]; then
		TKRSRC="${TKDIR}/lib/tkbase.res.o"
		if [ -f "${TKRSRC}" ]; then
			EXTRA_OBJS="${EXTRA_OBJS} ${TKRSRC}"

			echo ' *** Removing "kit.rc" since we have Tk with its own resource file'

			rm -f "${BUILDDIR}/kit.rc"
		fi
	fi

	# Cleanup
	rm -f kit kit.exe tclsh tclsh.exe

	# Determine if target is KitDLL or KitSH
	if [ "${KITTARGET}" = "kitdll" ]; then
		if [ "${KITCREATOR_STATIC_KITDLL}" = '1' ]; then
			CONFIGUREEXTRA="${CONFIGUREEXTRA} --enable-kitdll=static"
		else
			CONFIGUREEXTRA="${CONFIGUREEXTRA} --enable-kitdll"
		fi
	fi

	# Compile Kit
	if [ -z "${ZLIBDIR}" ]; then
		echo "Running: ./configure --with-tcl=\"${TCLCONFIGDIR}\" ${CONFIGUREEXTRA}"

		./configure --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}
	else
		echo "Running: ./configure --with-tcl=\"${TCLCONFIGDIR}\" --with-zlib=\"${ZLIBDIR}\" ${CONFIGUREEXTRA}"

		./configure --with-tcl="${TCLCONFIGDIR}" --with-zlib="${ZLIBDIR}" ${CONFIGUREEXTRA}
	fi

	echo "Running: ${MAKE:-make} TCLSH_NATIVE=\"${TCLSH_NATIVE}\""
	${MAKE:-make} TCLSH_NATIVE="${TCLSH_NATIVE}" || exit 1

	# Strip the kit of all symbols, if possible
	if ! echo " ${CONFIGUREEXTRA} " | grep ' --enable-symbols ' >/dev/null; then
		"${STRIP:-strip}" kit kit.exe >/dev/null 2>/dev/null
		"${STRIP:-strip}" -g libtclkit* >/dev/null 2>/dev/null
	fi

	# Fix up Win32 DLL names
	## .DLL.A -> .LIB
	for file in libtclkit*.dll.a; do
		if [ ! -f "${file}" ]; then
			continue
		fi

		newfile="$(basename "${file}" .dll.a).lib"
		mv "${file}" "${newfile}"
	done

	## .DLL.DEF -> .DEF
	for file in libtclkit*.dll.def; do
		if [ ! -f "${file}" ]; then
			continue
		fi

		newfile="$(basename "${file}" .dll.def).def"
		mv "${file}" "${newfile}"
	done

	# Determine name of created kit
	KITTARGET_NAME='__error__'
	if [ "${KITTARGET}" = "kitdll" ]; then
		## Find the library created
		for chkkittarget in libtclkit*.*; do
			if [ ! -f "${chkkittarget}" ]; then
				continue
			fi

			if echo "${chkkittarget}" | egrep '\..*\.(lib|def|a)$'; then
				continue
			fi

			KITTARGET_NAME="./${chkkittarget}"

			break
		done

		## Also create an executable named "kit" so that we can run it later
		eval tclshExtraMakeArgs=(${KC_KITSH_TCLSH_EXTRA_MAKE_ARGS})
		echo "Running: ${MAKE:-make} tclsh ${tclshExtraMakeArgs[@]}"
		${MAKE:-make} tclsh "${tclshExtraMakeArgs[@]}"
		if [ -f "tclsh.exe" ]; then
			cp tclsh.exe kit.exe
		else
			cp tclsh kit
		fi
	else
		## The executable is always named "kit"
		if [ -f 'kit.exe' ]; then
			KITTARGET_NAME='./kit.exe'
		else
			KITTARGET_NAME='./kit'
		fi
	fi
	export KITTARGET_NAME

	if [ "${KITTARGET_NAME}" = '__error__' ]; then
		echo "Failed to locate kit target!" >&2

		exit 1
	fi

	# Intall VFS onto kit
	## Determine if we have a Tclkit to do this work
	TCLKIT="${TCLKIT:-tclkit}"
	if echo 'exit 0' | "${TCLKIT}" >/dev/null 2>/dev/null; then
		## Install using existing Tclkit
		### Call installer
		echo "Running: \"${TCLKIT}\" installvfs.tcl \"${KITTARGET_NAME}\" starpack.vfs \"${ENABLECOMPRESSION}\" \"${KITTARGET_NAME}.new\""
		"${TCLKIT}" installvfs.tcl "${KITTARGET_NAME}" starpack.vfs "${ENABLECOMPRESSION}" "${KITTARGET_NAME}.new" || exit 1
	else
		if echo 'exit 0' | "${KITTARGET_NAME}" >/dev/null 2>/dev/null; then
			## Bootstrap (cannot cross-compile)
			### Call installer
			echo "set argv [list {${KITTARGET_NAME}} starpack.vfs {${ENABLECOMPRESSION}} {${KITTARGET_NAME}.new}]" > setup.tcl
			echo 'if {[catch { clock seconds }]} { proc clock args { return 0 } }' >> setup.tcl
			echo 'source installvfs.tcl' >> setup.tcl

			echo 'Running: echo | \"${KITTARGET_NAME}\" setup.tcl'
			echo | "${KITTARGET_NAME}" setup.tcl || exit 1
		else
			## Install using Tclsh, which may work if we're not using Metakit
			### Call installer
			echo "Running: \"${TCLSH_NATIVE}\" installvfs.tcl \"${KITTARGET_NAME}\" starpack.vfs \"${ENABLECOMPRESSION}\" \"${KITTARGET_NAME}.new\""
			"${TCLSH_NATIVE}" installvfs.tcl "${KITTARGET_NAME}" starpack.vfs "${ENABLECOMPRESSION}" "${KITTARGET_NAME}.new" || exit 1
		fi
	fi

	cp "${KITTARGET_NAME}.new" "${KITTARGET_NAME}"
	rm -f "${KITTARGET_NAME}.new"

	# Cleanup
	if [ "${KITTARGET}" = "kitdll" ]; then
		## Remove built interpreters if we are building KitDLL --
		## they're just tiny stubs anyway
		rm -f kit kit.exe
	fi

	exit 0
) || exit 1

exit 0
