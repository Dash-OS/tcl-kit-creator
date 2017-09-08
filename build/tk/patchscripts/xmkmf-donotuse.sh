#! /bin/bash

# If we are not cross-compiling then don't worry about replacing "xmkmf" with a wrapper
if [ -z "${KC_CROSSCOMPILE}" ]; then
	## If KC_CROSSCOMPILE was unspecified, try to autodetect
	if [ -z "${CC}" ]; then
		exit 0
	fi

	case "$(basename "${CC}")" in
		*-*-*)
			;;
		*)
			exit 0
	esac
else
	## If KC_CROSSCOMPILE was specified as 0, we are not cross-compiling
	if [ "${KC_CROSSCOMPILE}" = '0' ]; then
		exit 0
	fi

	## Otherwise, we are cross-compiling
fi

# Create an "xmkmf" wrapper which exits in failure so that autoconf will try
# to locate headers/libraries normally
mkdir fake-bin >/dev/null 2>/dev/null

cat << \_EOF_ > fake-bin/xmkmf
#! /bin/bash
exit 1
_EOF_

chmod +x fake-bin/xmkmf
