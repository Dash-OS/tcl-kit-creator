#! /usr/bin/env bash

# BuildCompatible: KitCreator

version="1.7.12"
url="http://tcltls.rkeene.org/uv/tcltls-${version}.tar.gz"
sha256='0e09e8e1cb3dcb3d419079fe40c521b7283d5e822dc914ffd1e4ff600b895caa'
configure_extra=('--enable-deterministic')

function buildSSLLibrary() {
	local version url hash
	local archive

	version='2.5.0'
	url="http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${version}.tar.gz"
	hash='8652bf6b55ab51fb37b686a3f604a2643e0e8fde2c56e6a936027d12afda6eae'

	archive="src/libressl-${version}.tar.gz"

	echo " *** Building LibreSSL v${version}" >&2

	if [ ! -e "${pkgdir}/${archive}" ]; then
		"${_download}" "${url}" "${pkgdir}/${archive}" "${hash}" || return 1
	fi

	(
		rm -rf libressl-*

		gzip -dc "${pkgdir}/${archive}" | tar -xf - || exit 1

		cd "libressl-${version}" || exit 1

		# This defeats hardening attempts that break on various platforms
		CFLAGS=' -g -O0 '
		export CFLAGS

		./configure ${CONFIGUREEXTRA} --disable-shared --enable-static --prefix="$(pwd)/INST" || exit 1

		# Disable building the apps -- they do not get used
		rm -rf apps
		mkdir apps
		cat << \_EOF_ > apps/Makefile
%:
	@echo Nothing to do
_EOF_

		${MAKE:-make} V=1 || exit 1

		${MAKE:-make} V=1 install || exit 1
	) || return 1

	# We always statically link
	KC_TLS_LINKSSLSTATIC='1'

	SSLDIR="$(pwd)/libressl-${version}/INST"

	PKG_CONFIG_PATH="${SSLDIR}/lib/pkgconfig:${PKG_CONFIG_PATH}"
	export PKG_CONFIG_PATH

	return 0
}

function preconfigure() {
	# Determine SSL directory
	if [ -z "${CPP}" ]; then
		CPP="${CC:-cc} -E"
	fi

	if [ -n "${KC_TLS_SSLDIR}" ]; then
		SSLDIR="${KC_TLS_SSLDIR}"
	else
		SSLDIR=''

		if [ -z "${KC_TLS_BUILDSSL}" ]; then
			SSLDIR="$(echo '#include <openssl/ssl.h>' 2>/dev/null | ${CPP} - 2> /dev/null | awk '/# 1 "\/.*\/ssl\.h/{ print $3; exit }' | sed 's@^"@@;s@"$@@;s@/include/openssl/ssl\.h$@@')"
		fi

		if [ -z "${SSLDIR}" ]; then
			buildSSLLibrary || SSLDIR=''
		fi

		if [ -z "${SSLDIR}" ]; then
			echo "Unable to find OpenSSL, aborting." >&2

			return 1
		fi
	fi

	# Add SSL library to configure options
	configure_extra=("${configure_extra[@]}" --with-openssl-dir="${SSLDIR}")

	# If we are statically linking to libssl, let tcltls know so it asks for the right
	# packages
	if [ "${KC_TLS_LINKSSLSTATIC}" = '1' ]; then
		configure_extra=("${configure_extra[@]}" --enable-static-ssl)
	fi
}

function postinstall() {
	for file in *.linkadd; do
		if [ ! -e "${file}" ]; then
			continue
		fi

		cp "${file}" "${installdir}/lib"/*/
	done
}
