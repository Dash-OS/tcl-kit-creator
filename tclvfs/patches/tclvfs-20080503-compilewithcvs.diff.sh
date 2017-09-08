#! /usr/bin/env bash

tclVersion="$1"
pkg="$2"
pkgVersion="$3"

case "${tclVersion}" in
	8.[012345]|8.[012345].*)
		exit 1
		;;
esac

exit 0
