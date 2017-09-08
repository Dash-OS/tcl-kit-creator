#! /usr/bin/env bash

targetInstallEnvironment='kitcreator'
pkgdir="$(pwd)"
internalpkgname="${pkg}"
archivedir="${pkgdir}/src"
buildsrcdir="${pkgdir}/buildsrc"
installdir="${pkgdir}/inst"
runtimedir="${pkgdir}/out"
patchdir="${pkgdir}/patches"
workdir="${pkgdir}/build/workdir-$$${RANDOM}${RANDOM}${RANDOM}${RANDOM}.work"

_download="$(which download)"

function clean() {
	rm -rf "${installdir}" "${runtimedir}"
}

function distclean() {
	rm -rf "${archivedir}"
	rm -rf "${pkgdir}"/build
}

function init_kitcreator() {
	:
}

function init() {
	clean || return 1

	TCL_VERSION="unknown"
	if [ -f "${TCLCONFIGDIR}/tclConfig.sh" ]; then
		source "${TCLCONFIGDIR}/tclConfig.sh" || return 1
	fi

	mkdir -p "${installdir}" "${runtimedir}" || return 1

	export TCL_VERSION

	init_kitcreator || return 1
}

function predownload() {
	:
}

function download() {
	if [ -d "${buildsrcdir}" ]; then
		return 0
	fi

	if [ -n "${url}" ]; then
		# Determine type of file
		archivetype="$(echo "${url}" | sed 's@\?.*$@@')"
		case "${archivetype}" in
			*.tar.*)
				archivetype="$(echo "${archivetype}" | sed 's@^.*\.tar\.@tar.@')"
				;;
			*)
				archivetype="$(echo "${archivetype}" | sed 's@^.*\.@@')"
				;;
		esac

		pkgarchive="${archivedir}/${pkg}-${version}.${archivetype}"
		mkdir "${archivedir}" >/dev/null 2>/dev/null
	fi

	if [ -n "${url}" -a -n "${pkgarchive}" -a ! -e "${pkgarchive}" ]; then
		"${_download}" "${url}" "${pkgarchive}" "${sha256}" || return 1
	fi

	return 0
}

function postdownload() {
	:
}

function extract() {
	if [ -d "${buildsrcdir}" ]; then
		mkdir -p "${workdir}" || return 1

		cp -rp "${buildsrcdir}"/* "${workdir}" || return 1

		return 0
	fi

	if [ -n "${pkgarchive}" ]; then
		(
			mkdir -p "${workdir}" || exit 1

			cd "${workdir}" || exit 1

			case "${pkgarchive}" in
				*.tar.gz|*.tgz)
					gzip -dc "${pkgarchive}" | tar -xf - || exit 1
					;;
				*.tar.bz2|*.tbz|*.tbz2)
					bzip2 -dc "${pkgarchive}" | tar -xf - || exit 1
					;;
				*.tar.xz|*.txz)
					xz -dc "${pkgarchive}" | tar -xf - || exit 1
					;;
				*.zip)
					unzip "${pkgarchive}" || exit 1
					;;
			esac

			shopt -s dotglob
			dir="$(echo ./*)"
			if [ -d "${dir}" ]; then
				mv "${dir}"/* . || exit 1

				rmdir "${dir}" || exit 1
			fi

			exit 0
		) || return 1
	fi

	return 0
}

function apply_patches() {
	local patch

	for patch in "${patchdir}/all"/${pkg}-${version}-*.diff "${patchdir}/${TCL_VERSION}"/${pkg}-${version}-*.diff "${patchdir}"/*.diff; do
		if [ ! -f "${patch}" ]; then
			continue
		fi

		if [ -x "${patch}.sh" ]; then
			if ! "${patch}.sh" "${TCL_VERSION}" "${pkg}" "${version}"; then
				continue
			fi
		fi

		echo "Applying: ${patch}"
		( cd "${workdir}" && ${PATCH:-patch} -p1 ) < "${patch}" || return 1
	done

	return 0
}

function preconfigure() {
	:
}

function configure() {
	local tryopts tryopt
	local staticpkg staticpkgvar
	local isshared
	local save_cflags
	local base_var kc_var

	# Determine if the user decided this should be static or not
	staticpkgvar="$(echo "STATIC${internalpkgname}" | dd conv=ucase 2>/dev/null)"
	staticpkg="$(eval "echo \"\$${staticpkgvar}\"")"

	# Determine if the build script overrides this
	if [ "${pkg_always_static}" = '1' ]; then
		staticpkg='1'
	fi

	# Set configure options for this sub-project
	for base_var in LDFLAGS CFLAGS CPPFLAGS LIBS; do
		kc_var="$(echo "KC_${internalpkgname}_${base_var}" | dd conv=ucase 2>/dev/null)"
		kc_var_val="$(eval "echo \"\$${kc_var}\"")"

		if [ -n "${kc_var_val}" ]; then
			eval "${base_var}=\"\$${base_var} \$${kc_var}\"; export ${base_var}"
		fi
	done

	# Determine if we should enable shared or not
	if [ "${staticpkg}" = "0" ]; then
		tryopts="--enable-shared --disable-shared"
	elif [ "${staticpkg}" = "-1" ]; then
		tryopts="--enable-shared"
	else
		tryopts="--disable-shared"
	fi

	save_cflags="${CFLAGS}"
	for tryopt in $tryopts __fail__; do
		if [ "${tryopt}" = "__fail__" ]; then
			return 1
		fi

		# Clean up, if needed
		make distclean >/dev/null 2>/dev/null
		if [ "${tryopt}" == "--enable-shared" ]; then
			isshared="1"
		else
			isshared="0"
		fi

		# If build a static package for KitDLL, ensure that we use PIC
		# so that it can be linked into the shared object
		if [ "${isshared}" = "0" -a "${KITTARGET}" = "kitdll" ]; then
			CFLAGS="${save_cflags} -fPIC"
		else
			CFLAGS="${save_cflags}"
		fi
		export CFLAGS

		if [ "${isshared}" = '0' ]; then
			pkg_configure_shared_build='0'
		else
			pkg_configure_shared_build='1'
		fi

		if [ "${isshared}" = '0' ]; then
			tryopt="${tryopt} --disable-stubs --enable-static"
		fi

		if ! grep '[-]-disable-stubs' configure >/dev/null 2>/dev/null; then
			if [ "${isshared}" = '0' ]; then
				sed 's@USE_TCL_STUBS@XXX_TCL_STUBS@g' configure > configure.new
			else
				sed 's@XXX_TCL_STUBS@USE_TCL_STUBS@g' configure > configure.new
			fi

			cat configure.new > configure
			rm -f configure.new
		fi

		./configure $tryopt --prefix="${installdir}" --exec-prefix="${installdir}" --libdir="${installdir}/lib" --with-tcl="${TCLCONFIGDIR}" "${configure_extra[@]}" ${CONFIGUREEXTRA} && break
	done

	return 0
}

function postconfigure() {
	:
}

function prebuild() {
	:
}

function build() {
	${MAKE:-make} tcllibdir="${installdir}/lib" "${make_extra[@]}"
}

function postbuild() {
	:
}

function preinstall() {
	:
}

function install() {
	mkdir -p "${installdir}/lib" || return 1
	${MAKE:-make} tcllibdir="${installdir}/lib" "${make_extra[@]}" install || return 1
}

function postinstall() {
	:
}

function createruntime() {
	local runtimelibdir
	local runtimepkgdir
	local pkglibfile
	local file

	# Install files needed by installation
	cp -r "${installdir}/lib" "${runtimedir}" || return 1

	# Create pkgIndex files if needed
	if [ -z "${tclpkg}" ]; then
		tclpkg="${pkg}"
	fi

	if [ -z "${tclpkgversion}" ]; then
		tclpkgversion="${version}"
	fi

	runtimelibdir="${runtimedir}/lib"

	if [ "${pkg_configure_shared_build}" = '0' ]; then
		find "${runtimelibdir}" -name '*.a' | sed 's@/[^/]*\.a$@@' | head -n 1 | while IFS='' read -r runtimepkgdir; do
			if [ ! -e "${runtimepkgdir}/pkgIndex.tcl" ]; then
				cat << _EOF_ > "${runtimepkgdir}/pkgIndex.tcl"
package ifneeded ${tclpkg} ${tclpkgversion} [list load {} ${tclpkg}]
_EOF_
			fi
		done
	elif [ "${pkg_configure_shared_build}" = '1' ]; then
		find "${runtimelibdir}" -name '*.so' -o -name '*.dylib' -o -name '*.dll' -o -name '*.shlib' | head -n 1 | while IFS='' read -r pkglibfile; do
			runtimepkgdir="$(echo "${pkglibfile}" | sed 's@/[^/]*$@@')"
			pkglibfile="$(echo "${pkglibfile}" | sed 's@^.*/@@')"
			if [ ! -e "${runtimepkgdir}/pkgIndex.tcl" ]; then
				cat << _EOF_ > "${runtimepkgdir}/pkgIndex.tcl"
package ifneeded ${tclpkg} ${tclpkgversion} [list load [file join \$dir ${pkglibfile}]]
_EOF_
			fi
		done
	fi

	# Remove link-only files from the runtime directory
	find "${runtimedir}" '(' -name '*.a' -o -name '*.a.linkadd' ')' -type f | while IFS='' read -r file; do
		rm -f "${file}"
	done

	# Ensure that some files were installed
	if ! find "${runtimedir}" -type f 2>/dev/null | grep '^' >/dev/null; then
		return 1
	fi

	return 0
}

function die() {
	local msg

	msg="$1"

	echo "$msg" >&2

	exit 1
}
