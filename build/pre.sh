#! /usr/bin/env bash

./kitcreator distclean >/dev/null 2>/dev/null

KITSHROOTDIR="$(ls -1d kitsh/buildsrc/kitsh-*/)"
export KITSHROOTDIR
(
	cd "${KITSHROOTDIR}" || exit 1

	autoconf; autoheader
	rm -rf autom4te.cache
	rm -f *~

	make -f Makefile.common.in boot.tcl.h zipvfs.tcl.h cvfs.tcl.h

	make distclean >/dev/null 2>/dev/null

	exit 0
) || exit 1

rm -f tcl/patchscripts/dietlibc.sh

find . -name '.*.sw?' -type f | xargs rm -f
