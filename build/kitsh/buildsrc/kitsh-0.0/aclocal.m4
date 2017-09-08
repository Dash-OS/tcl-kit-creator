AC_DEFUN(DC_DO_TCL, [
	AC_MSG_CHECKING([path to tcl])
	AC_ARG_WITH(tcl, AC_HELP_STRING([--with-tcl], [directory containing tcl configuration (tclConfig.sh)]), [], [
		with_tcl="auto"
	])

	if test "${with_tcl}" = "auto"; then
		for dir in `echo "${PATH}" | sed 's@:@ @g'`; do
			if test -f "${dir}/tclConfig.sh"; then
				tclconfigshdir="${dir}"
				tclconfigsh="${tclconfigshdir}/tclConfig.sh"
				break
			fi
			if test -f "${dir}/../lib/tclConfig.sh"; then
				tclconfigshdir="${dir}/../lib"
				tclconfigsh="${tclconfigshdir}/tclConfig.sh"
				break
			fi
			if test -f "${dir}/../lib64/tclConfig.sh"; then
				tclconfigshdir="${dir}/../lib64"
				tclconfigsh="${tclconfigshdir}/tclConfig.sh"
				break
			fi
		done

		if test -z "${tclconfigsh}"; then
			AC_MSG_ERROR([Unable to find tclConfig.sh])
		fi
	else
		tclconfigshdir="${with_tcl}"
		tclconfigsh="${tclconfigshdir}/tclConfig.sh"
	fi

	if test -f "${tclconfigsh}"; then
		. "${tclconfigsh}"

		CFLAGS="${CFLAGS} ${TCL_INCLUDE_SPEC} -I${TCL_SRC_DIR}/generic -I${tclconfigshdir}"
		CPPFLAGS="${CPPFLAGS} ${TCL_INCLUDE_SPEC} -I${TCL_SRC_DIR}/generic -I${tclconfigshdir}"
		LIBS="${LIBS} ${TCL_LIBS}"

		KITDLL_LIB_VERSION=`echo "${TCL_VERSION}${TCL_PATCH_LEVEL}" | sed 's@\.@@g'`
	fi

	AC_SUBST(CFLAGS)
	AC_SUBST(CPPFLAGS)
	AC_SUBST(LIBS)
	AC_SUBST(KITDLL_LIB_VERSION)

	AC_MSG_RESULT([$tclconfigsh])
])

AC_DEFUN(DC_DO_TK, [
	AC_MSG_CHECKING([path to tk])
	AC_ARG_WITH(tk, AC_HELP_STRING([--with-tk], [directory containing tk configuration (tkConfig.sh)]), [], [
		with_tk="auto"
	])

	if test "${with_tk}" = "auto"; then
		for dir in ../../../tk/build/tk*/*/ `echo "${PATH}" | sed 's@:@ @g'`; do
			if test -f "${dir}/tkConfig.sh"; then
				tkconfigshdir="${dir}"
				tkconfigsh="${tkconfigshdir}/tkConfig.sh"
				break
			fi
			if test -f "${dir}/../lib/tkConfig.sh"; then
				tkconfigshdir="${dir}/../lib"
				tkconfigsh="${tkconfigshdir}/tkConfig.sh"
				break
			fi
			if test -f "${dir}/../lib64/tkConfig.sh"; then
				tkconfigshdir="${dir}/../lib64"
				tkconfigsh="${tkconfigshdir}/tkConfig.sh"
				break
			fi
		done

		if test -z "${tkconfigsh}"; then
			AC_MSG_ERROR([Unable to find tkConfig.sh])
		fi
	else
		tkconfigshdir="${with_tk}"
		tkconfigsh="${tkconfigshdir}/tkConfig.sh"
	fi

	if test -f "${tkconfigsh}"; then
		. "${tkconfigsh}"

		CFLAGS="${CFLAGS} ${TK_INCLUDE_SPEC} -I${tkconfigshdir} -I${TK_SRC_DIR}/generic -I${TK_SRC_DIR}/xlib"
		CPPFLAGS="${CPPFLAGS} ${TK_INCLUDE_SPEC} -I${tkconfigshdir} -I${TK_SRC_DIR}/generic -I${TK_SRC_DIR}/xlib"
		LIBS="${LIBS} ${TK_LIBS}"

		NEWLIBS=""
		for lib in ${LIBS}; do
			if echo "${lib}" | grep '^-l' >/dev/null; then
				if echo " ${NEWLIBS} " | grep " ${lib} " >/dev/null; then
					continue
				fi
			fi

			NEWLIBS="${NEWLIBS} ${lib}"
		done
		LIBS="${NEWLIBS}"
		unset NEWLIBS
	fi

	AC_SUBST(CFLAGS)
	AC_SUBST(CPPFLAGS)
	AC_SUBST(LIBS)

	AC_MSG_RESULT([$tkconfigsh])
])

AC_DEFUN(DC_DO_STATIC_LINK_LIB, [
	AC_MSG_CHECKING([for how to statically link to $1])

	SAVELIBS="${LIBS}"
	staticlib=""
	found="0"
	dnl HP/UX uses -Wl,-a,archive -lstdc++ -Wl,-a,shared_archive
	dnl Linux and Solaris us -Wl,-Bstatic ... -Wl,-Bdynamic
	for trylink in "-Wl,-a,archive $2 -Wl,-a,shared_archive" "-Wl,-Bstatic $2 -Wl,-Bdynamic" "$2"; do
		if echo " ${LDFLAGS} " | grep ' -static ' >/dev/null; then
			if test "${trylink}" != "$2"; then
				continue
			fi
		fi

		LIBS="${SAVELIBS} ${trylink}"

		AC_LINK_IFELSE(AC_LANG_PROGRAM([], []), [
			staticlib="${trylink}"
			found="1"

			break
		])
	done

	if test "${found}" = "1"; then
		SAVELIBS=`echo "$SAVELIBS" | sed 's@ $2 @ @'`
		LIBS="${SAVELIBS} ${staticlib}"

		AC_MSG_RESULT([${staticlib}])

		AC_SUBST(LIBS)

		$3
	else
		LIBS="${SAVELIBS}"

		AC_MSG_RESULT([cant])

		$4
	fi
])

AC_DEFUN(DC_DO_STATIC_LINK_LIBCXX, [
	dnl Sun Studio uses -lCstd -lCrun, most platforms use -lstdc++
	DC_DO_STATIC_LINK_LIB([C++ Library (Sun Studio)], [-lCstd -lCrun],, [
		DC_DO_STATIC_LINK_LIB([C++ Library (UNIX)], [-lstdc++])
	])
])

AC_DEFUN(DC_FIND_TCLKIT_LIBS, [
	DC_SETUP_TCL_PLAT_DEFS

	dnl We will need this for the Tcl project, which we will always have
	DC_CHECK_FOR_WHOLE_ARCHIVE

	echo '/* Dynamically generated. */' > kitInit-libs.h
	libs_init_funcs=""

	for projdir in ../../../*/; do
		proj="`basename "${projdir}"`"
		subprojs="$proj"

		if test "${proj}" = "build"; then
			continue
		fi

		if test "${proj}" = "kitsh"; then
			continue
		fi

		if test "${proj}" = "common"; then
			continue
		fi

		projlibdir="../../../${proj}/inst"

		if test -d "${projlibdir}"; then
			true
		else
			continue
		fi

		AC_MSG_CHECKING([for libraries required for ${proj}])

		projlibfiles="`find "${projlibdir}" -name '*.a' 2>/dev/null | sort`"
		projexcludefile="${projlibdir}/kitcreator-nolibs"
		if test -e "${projexcludefile}"; then
			projexclude="`cat "$projexcludefile"`"
			projlibfiles="`echo "$projlibfiles" | egrep -v "$projexclude"`"
		fi

		projlibfilesnostub="`echo "$projlibfiles" | grep -v 'stub' | tr "\n" ' '`"
		projlibfiles="`echo "$projlibfiles" | tr "\n" ' '`"
		projlibextra=""

		if test "$projlibfilesnostub" = ' '; then
			projlibfilesnostub=''
		fi

		if test "$projlibfiles" = ' '; then
			projlibfiles=''
		fi

		projlibextra_static=''
		for libfile in ${projlibfilesnostub}; do
			if test -f "${libfile}.linkadd"; then
				projlibextra="`cat "${libfile}.linkadd"`"

				dnl Replace static linking requests with the appropriate values
				if echo "${projlibextra}" | grep '^#STATIC ' >/dev/null; then
					projlibextra_static="${projlibextra_static} `echo "${projlibextra}" | sed 's@^#STATIC @@'`"
					projlibextra=''
				fi
			fi
		done

		AC_MSG_RESULT([${projlibfilesnostub} ${projlibextra}])

		if test -n "${projlibextra_static}"; then
			DC_DO_STATIC_LINK_LIB([Additional libraries for ${proj}], ${projlibextra_static})
		fi

		hide_symbols="1"

		if test "${proj}" = "tcl"; then
			DC_TEST_WHOLE_ARCHIVE_SHARED_LIB([$ARCHS $projlibfilesnostub], [
				projlibfiles="${projlibfilesnostub}"
			], [
				DC_TEST_WHOLE_ARCHIVE_SHARED_LIB([$ARCHS $projlibfiles], [
					projlibfiles="${projlibfiles}"
				])
			])

			hide_symbols="0"
			subprojs="`echo " $projlibfilesnostub " | sed 's@ [[^ ]]*/@ @g;s@ lib@ @g;s@[[0-9\.]]*\.a@ @g;s@ tdbc[[^ ]]*@ @g;s@ sqlite @ sqlite3 @;s@ tcldde[[0-9]][[0-9]]*s*g* @ @g;s@ tclreg[[0-9]][[0-9]]*s*g* @ @g;s@ tcl[[0-9]]*s*g* @ @g;s@^ *@@;s@ *[$]@@'`"
		fi

		if test "${proj}" = "mk4tcl"; then
			if test -n "${projlibfiles}"; then
				AC_DEFINE(KIT_INCLUDES_MK4TCL, [1], [Specify this if you link against mkt4tcl])

				kc_cv_feature_kit_includes_mk4tcl='1'

				DC_DO_STATIC_LINK_LIBCXX
			fi

			subprojs=""
		fi

		if test "${proj}" = "tk"; then
			if test "${projlibfilesnostub}" != ""; then
				DC_DO_TK
				AC_DEFINE(KIT_INCLUDES_TK, [1], [Specify this if we link statically to Tk])
				if test -n "${TK_VERSION}"; then
					AC_DEFINE_UNQUOTED(KIT_TK_VERSION, "${TK_VERSION}${TK_PATCH_LEVEL}", [Specify the version of Tk])
				fi

				if test "$host_os" = "mingw32msvc" -o "$host_os" = "mingw32"; then
					AC_DEFINE(KITSH_NEED_WINMAIN, [1], [Define if you need WinMain (Windows)])
					CFLAGS="${CFLAGS} -mwindows"
				fi

				DC_TEST_WHOLE_ARCHIVE_SHARED_LIB([$ARCHS $projlibfilesnostub], [
					projlibfiles="${projlibfilesnostub}"
				], [
					DC_TEST_WHOLE_ARCHIVE_SHARED_LIB([$ARCHS $projlibfiles], [
						projlibfiles="${projlibfiles}"
					])
				])

				hide_symbols="0"
			fi

			subprojs=""
		fi

		if test "${proj}" = "tclvfs"; then
			subprojs=""
		fi

		if test "${hide_symbols}" = "1"; then
			STRIPLIBS="${STRIPLIBS} ${projlibfiles}"
		fi

		dnl Do not explicitly link to Zlib, that will happen elsewhere
		if test "${proj}" = "zlib"; then
			continue
		fi

		if test -n "${subprojs}"; then
			if test -n "${projlibfilesnostub}"; then
				for subproj in $subprojs; do
					subprojucase="`echo ${subproj} | dd conv=ucase 2>/dev/null`"
					subprojtcase="`echo ${subprojucase} | cut -c 1``echo ${subproj} | cut -c 2-`"
					lib_init_func="${subprojtcase}_Init"

					echo "#define KIT_INCLUDES_${subprojucase}" >> kitInit-libs.h
					echo "Tcl_AppInitProc ${lib_init_func};" >> kitInit-libs.h

					libs_init_funcs="${libs_init_funcs} ${lib_init_func}"
				done
			fi
		fi

		ARCHS="${ARCHS} ${projlibfiles}"
		LIBS="${LIBS} ${projlibextra}"
	done

	echo '' >> kitInit-libs.h
	echo 'static void _Tclkit_GenericLib_Init(void) {' >> kitInit-libs.h
	for lib_init_func in ${libs_init_funcs}; do
		proj="`echo ${lib_init_func} | sed 's@_Init$$@@@' | dd conv=lcase 2>/dev/null`"
		echo "	Tcl_StaticPackage(0, \"${proj}\", ${lib_init_func}, NULL);" >> kitInit-libs.h
	done
	echo '	return;' >> kitInit-libs.h
	echo '}' >> kitInit-libs.h

	AC_SUBST(ARCHS)
	AC_SUBST(STRIPLIBS)
	AC_SUBST(LIBS)
])

AC_DEFUN(DC_SETUP_TCL_PLAT_DEFS, [
	AC_CANONICAL_BUILD
	AC_CANONICAL_HOST
  
	AC_MSG_CHECKING(host operating system)
	AC_MSG_RESULT($host_os)
  
	case $host_os in
		mingw32*)
			CFLAGS="${CFLAGS} -mms-bitfields"
			WISH_CFLAGS="-mwindows"

			dnl If we are building for Win32, we need to define "BUILD_tcl" so that
			dnl TCL_STORAGE_CLASS gets defined as DLLEXPORT, to make static linking
			dnl work
			AC_DEFINE(BUILD_tcl, [1], [Define if you need to pretend to be building Tcl (Windows)])
			AC_DEFINE(BUILD_tk, [1], [Define if you need to pretend to be building Tk (Windows)])
			;;
		cygwin*)
			CFLAGS="${CFLAGS} -mms-bitfields"
			WISH_CFLAGS="-mwindows"
			;;
	esac

	AC_SUBST(WISH_CFLAGS)
])

AC_DEFUN(DC_STATIC_LIBGCC, [
	AC_MSG_CHECKING([how to link statically against libgcc])

	SAVELDFLAGS="${LDFLAGS}"
	staticlibgcc=""
	for trylink in "-static-libgcc"; do
		LDFLAGS="${SAVELDFLAGS} ${trylink}"
		AC_LINK_IFELSE(AC_LANG_PROGRAM([], []), [
			staticlibgcc="${trylink}"

			break
		])
	done
	if test -n "${staticlibgcc}"; then
		LDFLAGS="${SAVELDFLAGS} ${staticlibgcc}"
		AC_MSG_RESULT([${staticlibgcc}])
	else
		LDFLAGS="${SAVELDFLAGS}"
		AC_MSG_RESULT([not needed])
	fi

	AC_SUBST(LDFLAGS)
])

AC_DEFUN(DC_CHECK_FOR_ACCEPTABLE_DLADDR, [
	AC_CHECK_HEADERS(dlfcn.h)
	AC_CHECK_FUNCS(dladdr)

	AC_MSG_CHECKING([for acceptable dladdr])

	AC_LINK_IFELSE(
		AC_LANG_PROGRAM([[
#ifdef HAVE_DLFCN_H
#include <dlfcn.h>
#endif
			]], [[
char *x;
Dl_info syminfo;
dladdr((void *) 0, &syminfo);
x = syminfo.dli_fname;
			]]
		),
		[
			AC_MSG_RESULT([found])
			AC_DEFINE(HAVE_ACCEPTABLE_DLADDR, [1], [Define to 1 if you have an acceptable dladdr implementation with dli_fname])
		], [
			AC_MSG_RESULT([not found])
		]
	)
])

dnl Usage:
dnl    DC_TEST_SHOBJFLAGS(shobjflags, shobjldflags, action-if-not-found)
dnl
AC_DEFUN(DC_TEST_SHOBJFLAGS, [
  AC_SUBST(SHOBJFLAGS)
  AC_SUBST(SHOBJLDFLAGS)

  OLD_LDFLAGS="$LDFLAGS"
  SHOBJFLAGS=""

  LDFLAGS="$OLD_LDFLAGS $1 $2"

  AC_TRY_LINK([#include <stdio.h>
int unrestst(void);], [ printf("okay\n"); unrestst(); return(0); ], [ SHOBJFLAGS="$1"; SHOBJLDFLAGS="$2" ], [
  LDFLAGS="$OLD_LDFLAGS"
  $3
])

  LDFLAGS="$OLD_LDFLAGS"
])

AC_DEFUN(DC_GET_SHOBJFLAGS, [
  AC_SUBST(SHOBJFLAGS)
  AC_SUBST(SHOBJLDFLAGS)

  AC_MSG_CHECKING(how to create shared objects)

  if test -z "$SHOBJFLAGS" -a -z "$SHOBJLDFLAGS"; then
    DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-shared -rdynamic], [
      DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-shared], [
        DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-shared -rdynamic -mimpure-text], [
          DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-shared -mimpure-text], [
            DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-shared -rdynamic -Wl,-G,-z,textoff], [
              DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-shared -Wl,-G,-z,textoff], [
                DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-shared -dynamiclib -flat_namespace -undefined suppress -bind_at_load], [
                  DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-dynamiclib -flat_namespace -undefined suppress -bind_at_load], [
                    DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-Wl,-dynamiclib -Wl,-flat_namespace -Wl,-undefined,suppress -Wl,-bind_at_load], [
                      DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-dynamiclib -flat_namespace -undefined suppress], [
                        DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-dynamiclib], [
                          AC_MSG_RESULT(cant)
                          AC_MSG_ERROR([We are unable to make shared objects.])
                        ])
                      ])
                    ])
                  ])
                ])
              ])
            ])
          ])
        ])
      ])
    ])
  fi

  AC_MSG_RESULT($SHOBJLDFLAGS $SHOBJFLAGS)
])

AC_DEFUN(DC_CHK_OS_INFO, [
	AC_CANONICAL_BUILD
	AC_CANONICAL_HOST

	AC_SUBST(SHOBJEXT)
	AC_SUBST(AREXT)
        AC_SUBST(SHOBJFLAGS)
        AC_SUBST(SHOBJLDFLAGS)

        AC_MSG_CHECKING(host operating system)
        AC_MSG_RESULT($host_os)

	SHOBJEXT="so"
	AREXT="a"

        case $host_os in
                darwin*)
			SHOBJEXT="dylib"
                        ;;
		hpux*)
			SHOBJEXT="sl"
			;;
		mingw*)
			SHOBJEXT="dll"
			SHOBJFLAGS="-mms-bitfields -DPIC"
			SHOBJLDFLAGS='-shared -Wl,--dll -Wl,--enable-auto-image-base -Wl,--output-def,$[@].def,--out-implib,$[@].a -Wl,--export-all-symbols -Wl,--add-stdcall-alias'
			;;
	esac
])

AC_DEFUN(DC_TEST_WHOLE_ARCHIVE_SHARED_LIB, [

	SAVE_LIBS="${LIBS}"

	LIBS="${WHOLEARCHIVE} $1 ${NOWHOLEARCHIVE} ${SAVE_LIBS}"
	AC_LINK_IFELSE(
		AC_LANG_PROGRAM([[
			]], [[
			]]
		),
		[
			LIBS="${SAVE_LIBS}"

			$2
		], [
			LIBS="${SAVE_LIBS}"

			$3
		]
	)
])

AC_DEFUN(DC_CHECK_FOR_WHOLE_ARCHIVE, [
	AC_MSG_CHECKING([for how to link whole archive])

	SAVE_CFLAGS="${CFLAGS}"

	wholearchive=""

	for check in "-Wl,--whole-archive -Wl,--no-whole-archive" "-Wl,-z,allextract -Wl,-z,defaultextract"; do
		CFLAGS="${SAVE_CFLAGS} ${check}"

		AC_LINK_IFELSE(AC_LANG_PROGRAM([], []),
			[
				wholearchive="${check}"

				break
			]
		)

	done

	CFLAGS="${SAVE_CFLAGS}"

	if test -z "${wholearchive}"; then
		AC_MSG_RESULT([not found])
	else
		AC_MSG_RESULT([${wholearchive}])

		WHOLEARCHIVE=`echo "${wholearchive}" | cut -f 1 -d ' '`
		NOWHOLEARCHIVE=`echo "${wholearchive}" | cut -f 2 -d ' '`
	fi

	AC_SUBST(WHOLEARCHIVE)
	AC_SUBST(NOWHOLEARCHIVE)
])

AC_DEFUN(DC_SETLDRUNPATH, [
	OLD_LDFLAGS="${LDFLAGS}"

	for testldflags in "-Wl,-rpath -Wl,$1" "-Wl,-R -Wl,$1"; do
		LDFLAGS="${OLD_LDFLAGS} ${testldflags}"
		AC_TRY_LINK([#include <stdio.h>], [ return(0); ], [
			LDRUNPATH="$LDRUNPATH $testldflags"

			break
		])
	done

	LDFLAGS="${OLD_LDFLAGS}"

	AC_SUBST(LDRUNPATH)
])

AC_DEFUN(DC_SET_DIR2C_FLAGS, [
	AC_MSG_CHECKING([if we should obsufcate the CVFS])

	AC_ARG_WITH(obsfucated-cvfs, AC_HELP_STRING([--with-obsfucated-cvfs], [Obsfucate CVFS filesystem (requires --enable-kit-storage=cvfs)]), [
		obsfucate_cvfs=$withval
	], [
		obsfucate_cvfs='no'
	])

	case "$obsfucate_cvfs" in
		yes)
			AC_MSG_RESULT([yes])
			DIR2C_FLAGS='--obsfucate'
			;;
		*)
			AC_MSG_RESULT([no])
			DIR2C_FLAGS=''
			;;
	esac

	AC_SUBST(DIR2C_FLAGS)
])
