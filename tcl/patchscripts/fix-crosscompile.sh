#! /bin/bash

if [ "${KC_CROSSCOMPILE}" != '1' ]; then
	exit 0
fi

mkdir fake-bin

cat << \_EOF_ > fake-bin/fake-uname
#! /bin/bash

if [ "$1" == "--fake" ]; then
	echo "true"

	exit 0
fi

if [ -z "${KC_CROSSCOMPILE_HOST_OS}" ]; then
	# If not cross compiling, revert to system uname
	while [ "$(uname --fake 2>/dev/null)" == "true" -a -n "${PATH}" ]; do
		PATH="$(echo "${PATH}" | sed 's@^[^:]*$@@;s@^[^:]*:@@')"

		export PATH
	done

	if [ -z "${PATH}" ]; then
		exit 1
	fi

	exec uname "$@"
fi

# Determine release information
case "${KC_CROSSCOMPILE_HOST_OS}" in
	*-hpux11*)
		sysname="HP-UX"
		sysrelease="$(echo "${KC_CROSSCOMPILE_HOST_OS}" | sed 's@^.*-hpux@@')"
		;;
	*-solaris2*)
		sysname="SunOS"
		sysrelease="$(echo "${KC_CROSSCOMPILE_HOST_OS}" | sed 's@^.*-solaris@@;s@^2@5@')"
		;;
	*-linux*)
		sysname="Linux"
		sysrelease="2.6.5"
		;;
	*-netbsd*)
		sysname="NetBSD"
		sysrelease="$(echo "${KC_CROSSCOMPILE_HOST_OS}" | sed 's@^.*-netbsd@@;s@$@.0@')"
		;;
	*-freebsd*)
		sysname="FreeBSD"
		sysrelease="$(echo "${KC_CROSSCOMPILE_HOST_OS}" | sed 's@^.*-freebsd@@;s@$@.0-RELEASE@')"
		;;
	*-aix[0-9].*)
		sysname="AIX"
		sysrelease="$(echo "${KC_CROSSCOMPILE_HOST_OS}" | sed 's@.*-aix\([0-9]\..*\)@\1@')"
		;;
	*-*-darwin*)
		sysname="Darwin"
		sysrelease="$(echo "${KC_CROSSCOMPILE_HOST_OS}" | sed 's@.*-darwin\([0-9]*\)@\1@')"
		;;
esac

# Determine machine information
case "${KC_CROSSCOMPILE_HOST_OS}" in
	x86_64-*-darwin*)
		sysmachine="Intel"
		syscpu="x86_64"
		;;
	powerpc-*-darwin*)
		sysmachine="Power Macintosh"
		syscpu="powerpc"
		;;
	hppa64-*-hpux*)
		sysmachine="9000/859"
		;;
	i386-*-solaris*)
		sysmachine="i86pc"
		;;
	sparc-*-solaris*)
		sysmachine="sun4u"
		;;
	x86_64-*)
		sysmachine="x86_64"
		;;
	i?86-*)
		sysmachine="i686"
		;;
	ia64-*)
		sysmachine="ia64"
		;;
	arm-*|armel-*|armeb-*)
		sysmachine="armv7l"
		;;
	mipsel-*|mipseb-*)
		sysmachine="mips"
		;;
	powerpc-*)
		sysmachine="ppc"
		;;
esac

for arg in $(echo "$@" | sed 's@.@ & @g'); do
	case "${arg}" in
		-)
			continue
			;;
		v)
			retval="${retval} unknown"
			;;
		r)
			retval="${retval} ${sysrelease}"
			;;
		s)
			retval="${retval} ${sysname}"
			;;
		m)
			retval="${retval} ${sysmachine}"
			;;
		p)
			# XXX
			retval="${retval} ${syscpu}"
			;;
		n)
			retval="${retval} $(hostname)"
			;;
		a)
			retval="${sysname} $(hostname) ${sysrelease} ${sysversion} ${sysmachine} ${syscpu}"
			;;
	esac
done

echo "${retval}" | sed 's@^  *@@;s@  *$@@'
_EOF_

chmod +x fake-bin/fake-uname

sed 's|`uname |`'"$(pwd)"'/fake-bin/fake-uname |g' unix/configure > unix/configure.new
cat unix/configure.new > unix/configure
rm -f unix/configure.new

exit 0
