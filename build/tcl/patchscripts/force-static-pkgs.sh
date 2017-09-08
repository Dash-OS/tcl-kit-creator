#! /usr/bin/env bash

if [ "${KC_TCL_STATICPKGS}" != '1' ]; then
	exit 0
fi

for makefile in {unix,win,macosx}/Makefile.in; do
	if [ ! -f "${makefile}" ]; then
		continue
	fi

	sed 's@--enable-shared@--disable-shared CFLAGS="-fPIC" @g' "${makefile}" > "${makefile}.new"
	cat "${makefile}.new" > "${makefile}"
	rm -f "${makefile}.new"
done

for pkgIndexFile in pkgs/*/pkgIndex*; do
	sed 's@load \[file join [^]]*\]@load {}@;s@\(Thread.* \[list load {}\)\]@\1 Thread]@' "${pkgIndexFile}" > "${pkgIndexFile}.new"
	cat "${pkgIndexFile}.new" > "${pkgIndexFile}"
	rm -f "${pkgIndexFile}.new"
done

for makefile in pkgs/*/Makefile*; do
	sed 's@x\$(SHARED_BUILD)@x1@g' "${makefile}" > "${makefile}.new"
	cat "${makefile}.new" > "${makefile}"
	rm -f "${makefile}.new"
done
