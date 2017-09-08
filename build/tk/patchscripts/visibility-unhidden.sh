#! /usr/bin/env bash

if [ "${KITTARGET}" != "kitdll" ]; then
	exit 0
fi

for file in unix/configure; do
	sed 's@-fvisibility@-__disabled__fvisibility@' "${file}" > "${file}.new"
	cat "${file}.new" > "${file}"
	rm -f "${file}.new"
done
