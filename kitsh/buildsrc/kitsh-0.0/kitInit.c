/* 
 * tclAppInit.c --
 *
 *  Provides a default version of the main program and Tcl_AppInit
 *  procedure for Tcl applications (without Tk).  Note that this
 *  program must be built in Win32 console mode to work properly.
 *
 * Copyright (c) 1996-1997 by Sun Microsystems, Inc.
 * Copyright (c) 1998-1999 by Scriptics Corporation.
 * Copyright (c) 2000-2002 Jean-Claude Wippler <jcw@equi4.com>
 *
 * See the file "license.terms" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 *
 * RCS: @(#) $Id$
 */

#ifdef KIT_INCLUDES_TK
#  include <tk.h>
#endif /* KIT_INCLUDES_TK */
#include <tcl.h>

#ifdef _WIN32
#  define WIN32_LEAN_AND_MEAN
#  include <windows.h>
#  undef WIN32_LEAN_AND_MEAN
#endif /* _WIN32 */

#ifndef MB_TASKMODAL
#  define MB_TASKMODAL 0
#endif /* MB_TASKMODAL */

#include "tclInt.h"

#ifdef HAVE_UNISTD_H
#  include <unistd.h>
#endif
#ifdef HAVE_STRING_H
#  include <string.h>
#endif
#ifdef HAVE_STRINGS_H
#  include <strings.h>
#endif

/* For dladdr() and Dl_info */
#ifdef HAVE_DLFCN_H
#  include <dlfcn.h>
#endif

#if defined(HAVE_TCL_GETENCODINGNAMEFROMENVIRONMENT) && defined(HAVE_TCL_SETSYSTEMENCODING)
#  define TCLKIT_CAN_SET_ENCODING 1
#endif
#if 10 * TCL_MAJOR_VERSION + TCL_MINOR_VERSION < 85
#  define TCLKIT_REQUIRE_TCLEXECUTABLENAME 1
#endif

#if 10 * TCL_MAJOR_VERSION + TCL_MINOR_VERSION < 85
#  define KIT_INCLUDES_PWB 1
#endif
#if 10 * TCL_MAJOR_VERSION + TCL_MINOR_VERSION < 86
#  define KIT_INCLUDES_ZLIB 1
#endif

#include "kitInit-libs.h"

#ifdef KIT_INCLUDES_MK4TCL
Tcl_AppInitProc	Mk4tcl_Init;
#endif
Tcl_AppInitProc Vfs_Init, Rechan_Init;
#ifdef KIT_INCLUDES_PWB
Tcl_AppInitProc	Pwb_Init;
#endif
#ifdef KIT_INCLUDES_ZLIB
Tcl_AppInitProc Zlib_Init;
#endif
#ifdef KIT_STORAGE_CVFS
Tcl_AppInitProc Cvfs_data_tcl_Init;
#endif
#ifdef TCL_THREADS
Tcl_AppInitProc	Thread_Init;
#endif
#ifdef _WIN32
Tcl_AppInitProc	Dde_Init, Registry_Init;
#endif

#ifdef TCLKIT_DLL
#  define TCLKIT_MOUNTPOINT "/.KITDLL_TCL"
#  define TCLKIT_VFSSOURCE "$::tclKitFilename"
#else
#  define TCLKIT_MOUNTPOINT "[info nameofexecutable]"
#  define TCLKIT_VFSSOURCE "[info nameofexecutable]"
#endif /* TCLKIT_DLL */

#ifndef TCLKIT_DLL
#  ifdef HAVE_ACCEPTABLE_DLADDR
#    ifdef KITSH_NEED_WINMAIN
#      ifdef _WIN32_WCE
int wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpszCmdLine, int nCmdShow);
#      else
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpszCmdLine, int nCmdShow);
#      endif /* _WIN32_WCE */
#    endif /* KITSH_NEED_WINMAIN */
int main(int argc, char **argv);
#  endif /* HAVE_ACCEPTABLE_DLADDR */
#endif /* !TCLKIT_DLL */

#ifdef TCLKIT_DLL
void __attribute__((constructor)) _Tclkit_Init(void);
#else
static void _Tclkit_Init(void);
#endif

#ifdef TCLKIT_REQUIRE_TCLEXECUTABLENAME
char *tclExecutableName;
#endif

/*
 *  Attempt to load a "boot.tcl" entry from the embedded MetaKit file.
 */
/*
 * This Tcl code is invoked whenever Tcl_Init() is called on an
 * interpreter.  It should mount up the VFS and make everything ready for
 * that interpreter to do its job.
 */
static char *preInitCmd = 
#if defined(_WIN32_WCE) && !defined(TCLKIT_DLL)
/* silly hack to get wince port to launch, some sort of std{in,out,err} problem */
"open /kitout.txt a; open /kitout.txt a; open /kitout.txt a\n"
/* this too seems to be needed on wince - it appears to be related to the above */
"catch {rename source ::tcl::source}\n"
"proc source file {\n"
	"set old [info script]\n"
	"info script $file\n"
	"set fid [open $file]\n"
	"set data [read $fid]\n"
	"close $fid\n"
	"set code [catch {uplevel 1 $data} res]\n"
	"info script $old\n"
	"if {$code == 2} { set code 0 }\n"
	"return -code $code $res\n"
"}\n"
#endif /* _WIN32_WCE && !TCLKIT_DLL */
"proc tclKitInit {} {\n"
	"rename tclKitInit {}\n"
	"catch { load {} vfs }\n"
#ifdef KIT_INCLUDES_ZLIB
	"catch { load {} zlib }\n"
#endif
#ifdef KIT_INCLUDES_MK4TCL
	"catch { load {} Mk4tcl }\n"
#endif
	"load {} tclkit::init\n"
	"::tclkit::init::initInterp\n"
	"rename ::tclkit::init::initInterp {}\n"
	"set bootfile [file join " TCLKIT_MOUNTPOINT " boot.tcl]\n"
	"if {[file exists $bootfile]} {\n"
		"catch {\n"
			"set f [open $bootfile]\n"
			"set s [read $f]\n"
			"close $f\n"
		"}\n"
	"} else {\n"
		"set ::TCLKIT_INITVFS 1\n"
	"}\n"
#ifdef KIT_STORAGE_MK4
	"set ::tclKitStorage \"mk4\"\n"
	"if {![info exists s]} {\n"
		"mk::file open exe " TCLKIT_VFSSOURCE " -readonly\n"
		"set n [mk::select exe.dirs!0.files name boot.tcl]\n"
		"if {$n != \"\"} {\n"
			"set s [mk::get exe.dirs!0.files!$n contents]\n"
			"if {![string length $s]} { error \"empty boot.tcl\" }\n"
			"catch {load {} zlib}\n"
			"if {[mk::get exe.dirs!0.files!$n size] != [string length $s]} {\n"
				"set s [zlib decompress $s]\n"
			"}\n"
		"}\n"
	"}\n"
#endif /* KIT_STORAGE_MK4 */
#ifdef KIT_STORAGE_ZIP
	"set ::tclKitStorage \"zip\"\n"
	"if {![info exists s]} {\n"
#  include "zipvfs.tcl.h"
		"catch {\n"
			"set ::tclKitStorage_fd [::zip::open " TCLKIT_VFSSOURCE "]\n"
			"::zip::stat $::tclKitStorage_fd boot.tcl sb\n"
			"seek $::tclKitStorage_fd $sb(ino)\n"
			"::zip::Data $::tclKitStorage_fd sb s\n"
		"}\n"
	"}\n"
#endif /* KIT_STORAGE_ZIP */
#ifdef KIT_STORAGE_CVFS
	"set ::tclKitStorage \"cvfs\"\n"
	"load {} rechan\n"
	"load {} cvfs_data_tcl\n"
#include "cvfs.tcl.h"
	"if {![info exists s]} {\n"
		"catch {\n"
			"set s [::vfs::cvfs::data::getData tcl boot.tcl]\n"
		"}\n"
	"}\n"
#endif /* KIT_STORAGE_CVFS */
	"if {![info exists s]} {\n"
		"set s \"\"\n"
	"}\n"
#ifdef TCLKIT_DLL
	"set ::TCLKIT_TYPE \"kitdll\"\n"
#else
	"set ::TCLKIT_TYPE \"tclkit\"\n"
#endif /* TCLKIT_DLL */
	"set ::TCLKIT_MOUNTPOINT " TCLKIT_MOUNTPOINT "\n"
	"catch { set ::TCLKIT_VFSSOURCE " TCLKIT_VFSSOURCE " }\n"
	"set ::TCLKIT_MOUNTPOINT_VAR {" TCLKIT_MOUNTPOINT "}\n"
	"set ::TCLKIT_VFSSOURCE_VAR {" TCLKIT_VFSSOURCE "}\n"
	"uplevel #0 $s\n"
#if defined(KIT_INCLUDES_TK) && defined(KIT_TK_VERSION)
	"package ifneeded Tk " KIT_TK_VERSION " {\n"
		"load {} Tk\n"
	"}\n"
#endif
#ifdef _WIN32
	"catch {load {} dde}\n"
	"catch {load {} registry}\n"
#endif /* _WIN32 */
	"return 0\n"
"}\n"
"tclKitInit";

static const char initScript[] =
"if {[file isfile [file join " TCLKIT_VFSSOURCE " main.tcl]]} {\n"
	"if {[info commands console] != {}} { console hide }\n"
	"set tcl_interactive 0\n"
	"incr argc\n"
	"set argv [linsert $argv 0 $argv0]\n"
	"set argv0 [file join " TCLKIT_VFSSOURCE " main.tcl]\n"
"} else continue\n";

/* SetExecName --

   Hack to get around Tcl bug 1224888.
*/
static void SetExecName(Tcl_Interp *interp, const char *path) {
#ifdef TCLKIT_REQUIRE_TCLEXECUTABLENAME
	tclExecutableName = strdup(path);
#endif
	Tcl_FindExecutable(path);

	return;
}

static void FindAndSetExecName(Tcl_Interp *interp) {
	int len = 0;
	Tcl_Obj *execNameObj;
	Tcl_Obj *lobjv[1];
#ifdef HAVE_READLINK
	ssize_t readlink_ret;
	char exe_buf[4096];
#endif /* HAVE_READLINK */
#ifdef HAVE_ACCEPTABLE_DLADDR
	Dl_info syminfo;
	int dladdr_ret;
#endif /* HAVE_ACCEPTABLE_DLADDR */ 

#ifdef HAVE_READLINK
	if (Tcl_GetNameOfExecutable() == NULL) {
		readlink_ret = readlink("/proc/self/exe", exe_buf, sizeof(exe_buf) - 1);

		if (readlink_ret > 0 && readlink_ret < (sizeof(exe_buf) - 1)) {
			exe_buf[readlink_ret] = '\0';

			SetExecName(interp, exe_buf);

			return;
		}
	}

	if (Tcl_GetNameOfExecutable() == NULL) {
		readlink_ret = readlink("/proc/curproc/file", exe_buf, sizeof(exe_buf) - 1);

		if (readlink_ret > 0 && readlink_ret < (sizeof(exe_buf) - 1)) {
			exe_buf[readlink_ret] = '\0';

			if (strcmp(exe_buf, "unknown") != 0) {
				SetExecName(interp, exe_buf);

				return;
			}
		}
	}
#endif /* HAVE_READLINK */

#ifdef HAVE_ACCEPTABLE_DLADDR
#  ifndef TCLKIT_DLL
	if (Tcl_GetNameOfExecutable() == NULL) {
		dladdr_ret = dladdr(&SetExecName, &syminfo);
		if (dladdr_ret != 0) {
			SetExecName(interp, syminfo.dli_fname);

			return;
		}
	}
#    ifdef KITSH_NEED_WINMAIN
	if (Tcl_GetNameOfExecutable() == NULL) {
#      ifdef _WIN32_WCE
		dladdr_ret = dladdr(&WinMain, &syminfo);
#      else
		dladdr_ret = dladdr(&wWinMain, &syminfo);
#      endif /* _WIN32_WCE */

		if (dladdr_ret != 0) {
			SetExecName(interp, syminfo.dli_fname);

			return;
		}
	}
#    endif /* KITSH_NEED_WINMAIN */

	if (Tcl_GetNameOfExecutable() == NULL) {
		dladdr_ret = dladdr(&main, &syminfo);
		if (dladdr_ret != 0) {
			SetExecName(interp, syminfo.dli_fname);

			return;
		}
	}
#  endif /* !TCLKIT_DLL */
#endif /* HAVE_ACCEPTABLE_DLADDR */

	if (Tcl_GetNameOfExecutable() == NULL) {
		lobjv[0] = Tcl_GetVar2Ex(interp, "argv0", NULL, TCL_GLOBAL_ONLY);
		execNameObj = Tcl_FSJoinToPath(Tcl_FSGetCwd(interp), 1, lobjv);

		SetExecName(interp, Tcl_GetStringFromObj(execNameObj, &len));

		return;
	}

	return;
}

static void _Tclkit_Generic_Init(void) {
#ifdef KIT_INCLUDES_MK4TCL
	Tcl_StaticPackage(0, "Mk4tcl", Mk4tcl_Init, NULL);
#endif
#ifdef KIT_INCLUDES_PWB
	Tcl_StaticPackage(0, "pwb", Pwb_Init, NULL);
#endif 
	Tcl_StaticPackage(0, "rechan", Rechan_Init, NULL);
	Tcl_StaticPackage(0, "vfs", Vfs_Init, NULL);
#ifdef KIT_INCLUDES_ZLIB
	Tcl_StaticPackage(0, "zlib", Zlib_Init, NULL);
#endif
#ifdef KIT_STORAGE_CVFS
	Tcl_StaticPackage(0, "cvfs_data_tcl", Cvfs_data_tcl_Init, NULL);
#endif
#ifdef TCL_THREADS
	Tcl_StaticPackage(0, "Thread", Thread_Init, NULL);
#endif
#ifdef _WIN32
	Tcl_StaticPackage(0, "dde", Dde_Init, NULL);
	Tcl_StaticPackage(0, "registry", Registry_Init, NULL);
#endif
#ifdef KIT_INCLUDES_TK
	Tcl_StaticPackage(0, "Tk", Tk_Init, Tk_SafeInit);
#endif

	_Tclkit_GenericLib_Init();

	TclSetPreInitScript(preInitCmd);

	return;
}

static void _Tclkit_Interp_Init(Tcl_Interp *interp) {
#ifdef TCLKIT_CAN_SET_ENCODING
	Tcl_DString encodingName;
#endif /* TCLKIT_CAN_SET_ENCODING */

#ifndef TCLKIT_DLL
	/* the tcl_rcFileName variable only exists in the initial interpreter */
#  ifdef _WIN32
	Tcl_SetVar(interp, "tcl_rcFileName", "~/tclkitrc.tcl", TCL_GLOBAL_ONLY);
#  else
	Tcl_SetVar(interp, "tcl_rcFileName", "~/.tclkitrc", TCL_GLOBAL_ONLY);
#  endif /* _WIN32 */
#endif /* !TCLKIT_DLL */

#ifdef TCLKIT_CAN_SET_ENCODING
	/* Set the encoding from the Environment */
	Tcl_GetEncodingNameFromEnvironment(&encodingName);
	Tcl_SetSystemEncoding(NULL, Tcl_DStringValue(&encodingName));
	Tcl_SetVar(interp, "tclkit_system_encoding", Tcl_DStringValue(&encodingName), 0);
	Tcl_DStringFree(&encodingName);
#endif /* TCLKIT_CAN_SET_ENCODING */

	/* Hack to get around Tcl bug 1224888.  This must be run here and
	 * in LibraryPathObjCmd because this information is needed both
	 * before and after that command is run. */
	FindAndSetExecName(interp);

#if defined(_WIN32) && defined(KIT_INCLUDES_TK)
	/* Every interpreter needs this done */
	Tk_InitConsoleChannels(interp);
#endif /* _WIN32 and KIT_INCLUDES_TK */

	return;
}

#ifndef TCLKIT_DLL
int TclKit_AppInit(Tcl_Interp *interp) {
#ifdef KIT_INCLUDES_TK
#  ifdef _WIN32
#    ifndef _WIN32_WCE
	char msgBuf[2049];
#    endif /* !_WIN32_WCE */
#  endif /* _WIN32 */
#endif /* KIT_INCLUDES_TK */

	/* Perform common initialization */
	_Tclkit_Init();

	if (Tcl_Init(interp) == TCL_ERROR) {
		goto error;
	}

#ifdef KIT_INCLUDES_TK
#  ifdef _WIN32
	if (Tk_Init(interp) == TCL_ERROR) {
		goto error;
	}
	if (Tk_CreateConsoleWindow(interp) == TCL_ERROR) {
		goto error;
	}
#  endif /* _WIN32 */
#endif /* KIT_INCLUDES_TK */

	/* messy because TclSetStartupScriptPath is called slightly too late */
	if (Tcl_Eval(interp, initScript) == TCL_OK) {
		Tcl_Obj* path;
#ifdef HAVE_TCLSETSTARTUPSCRIPTPATH
		path = TclGetStartupScriptPath();
		TclSetStartupScriptPath(Tcl_GetObjResult(interp));
#elif defined(HAVE_TCL_SETSTARTUPSCRIPT)
		path = Tcl_GetStartupScript(NULL);
		Tcl_SetStartupScript(Tcl_GetObjResult(interp), NULL);
#endif
		if (path == NULL) {
			Tcl_Eval(interp, "incr argc -1; set argv [lrange $argv 1 end]");
		}
	}

	Tcl_SetVar(interp, "errorInfo", "", TCL_GLOBAL_ONLY);
	Tcl_ResetResult(interp);

	return TCL_OK;

error:
#ifdef KIT_INCLUDES_TK
#  ifdef _WIN32
	MessageBeep(MB_ICONEXCLAMATION);
#    ifndef _WIN32_WCE
	snprintf(msgBuf, sizeof(msgBuf),
		"A critical error has occurred.  Please report this to the Tclkit vendor.\nInterpreter Returned: %s\nError Info: %s",
		Tcl_GetStringResult(interp),
		Tcl_GetVar(interp, "errorInfo", TCL_GLOBAL_ONLY));

	MessageBox(NULL, msgBuf, "Error in TclKit",
		MB_ICONSTOP | MB_OK | MB_TASKMODAL | MB_SETFOREGROUND);

	ExitProcess(1);
#    endif /* !_WIN32_WCE */
    /* we won't reach this, but we need the return */
#  endif /* _WIN32 */
#endif /* KIT_INCLUDES_TK */

	return TCL_ERROR;
}
#endif /* !TCLKIT_DLL */


#ifdef TCLKIT_DLL
#  ifdef HAVE_ACCEPTABLE_DLADDR
/* Symbol to resolve against dladdr() */
static void _tclkit_dummy_func(void) {
	return;
}
#  endif /* HAVE_ACCEPTABLE_DLADDR */

/*
 * This function will return a pathname we can open() to treat as a VFS,
 * hopefully
 */
static char *find_tclkit_dll_path(void) {
#ifdef HAVE_ACCEPTABLE_DLADDR
	Dl_info syminfo;
	int dladdr_ret;
#endif /* HAVE_ACCEPTABLE_DLADDR */
#ifdef _WIN32
	TCHAR modulename[8192];
	DWORD gmfn_ret;
#endif /* _WIN32 */

#ifdef HAVE_ACCEPTABLE_DLADDR
	dladdr_ret = dladdr(&_tclkit_dummy_func, &syminfo);
	if (dladdr_ret != 0) {
		if (syminfo.dli_fname && syminfo.dli_fname[0] != '\0') {
			return(strdup(syminfo.dli_fname));
		}
	}
#endif /* HAVE_ACCEPTABLE_DLADDR */

#ifdef _WIN32
	gmfn_ret = GetModuleFileName(TclWinGetTclInstance(), modulename, sizeof(modulename) / sizeof(modulename[0]) - 1);

	if (gmfn_ret != 0) {
		return(strdup(modulename));
	}
#endif /* _WIN32 */

	return(NULL);
}
#else
# define find_tclkit_dll_path() NULL
#endif

/*
 * This function exists to allow C code to initialize a particular
 * interpreter.
 */
static int tclkit_init_initinterp(ClientData cd, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
	char *kitdll_path;

	kitdll_path = find_tclkit_dll_path();
	if (kitdll_path != NULL) {
		Tcl_SetVar(interp, "tclKitFilename", kitdll_path, TCL_GLOBAL_ONLY);

		free(kitdll_path);
	}

	_Tclkit_Interp_Init(interp);

	return(TCL_OK);
}

/*
 * Create a package for initializing a particular interpreter.  This is
 * our hook to have Tcl invoke C commands when creating an interpreter.
 * The preInitCmd will load the package in the new interpreter and invoke
 * this function.
 */
int Tclkit_init_Init(Tcl_Interp *interp) {
	Tcl_Command tclCreatComm_ret;
	int tclPkgProv_ret;

	tclCreatComm_ret = Tcl_CreateObjCommand(interp, "::tclkit::init::initInterp", tclkit_init_initinterp, NULL, NULL);
	if (!tclCreatComm_ret) {
		return(TCL_ERROR);
	}

	tclPkgProv_ret = Tcl_PkgProvide(interp, "tclkit::init", "1.0");

	return(tclPkgProv_ret);
}

/*
 * Initialize the Tcl system when we are loaded, that way Tcl functions
 * are ready to be used when invoked.
 */
#ifdef TCLKIT_DLL
void __attribute__((constructor)) _Tclkit_Init(void) {
#else
static void _Tclkit_Init(void) {
#endif
	static int called = 0;

	if (called) {
		return;
	}

	called = 1;

	Tcl_StaticPackage(0, "tclkit::init", Tclkit_init_Init, NULL);

	_Tclkit_Generic_Init();

	return;
}

#if defined(TCLKIT_DLL) && defined(TCLKIT_DLL_STATIC)
int Tcl_InitReal(Tcl_Interp *interp);

int Tcl_Init(Tcl_Interp *interp) {
	_Tclkit_Init();

	return(Tcl_InitReal(interp));
}
#endif
