#ifdef KITSH_NEED_WINMAIN
/* 
 * winMain.c --
 *
 *	Main entry point for wish and other Tk-based applications.
 *
 * Copyright (c) 1995-1997 Sun Microsystems, Inc.
 * Copyright (c) 1998-1999 by Scriptics Corporation.
 *
 * See the file "license.terms" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 *
 * RCS: @(#) $Id: winMain.c 1629 2007-06-09 13:59:31Z jcw $
 */

#include <tk.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#undef WIN32_LEAN_AND_MEAN
#include <malloc.h>

#ifndef UNDER_CE
#include <locale.h>
#endif

/*
 * The following declarations refer to internal Tk routines.  These
 * interfaces are available for use, but are not supported.
 */


/*
 * Forward declarations for procedures defined later in this file:
 */

static void		setargv _ANSI_ARGS_((int *argcPtr, char ***argvPtr));
static Tcl_PanicProc	WishPanic;

static BOOL consoleRequired = TRUE;

/*
 * The following #if block allows you to change the AppInit
 * function by using a #define of TCL_LOCAL_APPINIT instead
 * of rewriting this entire file.  The #if checks for that
 * #define and uses Tcl_AppInit if it doesn't exist.
 */
    
#ifndef TK_LOCAL_APPINIT
#define TK_LOCAL_APPINIT Tcl_AppInit    
#endif
extern int TK_LOCAL_APPINIT _ANSI_ARGS_((Tcl_Interp *interp));
    
/*
 * The following #if block allows you to change how Tcl finds the startup
 * script, prime the library or encoding paths, fiddle with the argv,
 * etc., without needing to rewrite Tk_Main()
 */

#ifdef TK_LOCAL_MAIN_HOOK
extern int TK_LOCAL_MAIN_HOOK _ANSI_ARGS_((int *argc, char ***argv));
#endif


/*
 *----------------------------------------------------------------------
 *
 * WinMain --
 *
 *	Main entry point from Windows.
 *
 * Results:
 *	Returns false if initialization fails, otherwise it never
 *	returns. 
 *
 * Side effects:
 *	Just about anything, since from here we call arbitrary Tcl code.
 *
 *----------------------------------------------------------------------
 */

int APIENTRY
#ifdef UNDER_CE
wWinMain(hInstance, hPrevInstance, lpszCmdLine, nCmdShow)
#else
WinMain(hInstance, hPrevInstance, lpszCmdLine, nCmdShow)
#endif
    HINSTANCE hInstance;
    HINSTANCE hPrevInstance;
    LPSTR lpszCmdLine;
    int nCmdShow;
{
    char **argv;
    int argc;
#ifndef UNDER_CE
    char buffer[MAX_PATH+1];
    char *p;
#endif

#ifdef UNDER_CE
    nCmdShow = SW_SHOWNORMAL;

    XCEShowWaitCursor();

    xceinit(lpszCmdLine);
    argc = __xceargc;
    argv = __xceargv;
#endif

    Tcl_SetPanicProc(WishPanic);

    /*
     * Create the console channels and install them as the standard
     * channels.  All I/O will be discarded until Tk_CreateConsoleWindow is
     * called to attach the console to a text widget.
     */

    consoleRequired = TRUE;

    /*
     * Set up the default locale to be standard "C" locale so parsing
     * is performed correctly.
     */

#ifndef UNDER_CE
    setlocale(LC_ALL, "C");
    setargv(&argc, &argv);

    /*
     * Replace argv[0] with full pathname of executable, and forward
     * slashes substituted for backslashes.
     */

    GetModuleFileName(NULL, buffer, sizeof(buffer));
    argv[0] = buffer;
    for (p = buffer; *p != '\0'; p++) {
	if (*p == '\\') {
	    *p = '/';
	}
    }
#endif

#ifdef TK_LOCAL_MAIN_HOOK
    TK_LOCAL_MAIN_HOOK(&argc, &argv);
#endif

    Tk_Main(argc, argv, TK_LOCAL_APPINIT);
    return 1;
}


/*
 *----------------------------------------------------------------------
 *
 * Tcl_AppInit --
 *
 *	This procedure performs application-specific initialization.
 *	Most applications, especially those that incorporate additional
 *	packages, will have their own version of this procedure.
 *
 * Results:
 *	Returns a standard Tcl completion code, and leaves an error
 *	message in the interp's result if an error occurs.
 *
 * Side effects:
 *	Depends on the startup script.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_AppInit(interp)
    Tcl_Interp *interp;		/* Interpreter for application. */
{
    if (Tcl_Init(interp) == TCL_ERROR) {
	goto error;
    }
    if (Tk_Init(interp) == TCL_ERROR) {
	goto error;
    }
    Tcl_StaticPackage(interp, "Tk", Tk_Init, Tk_SafeInit);

    /*
     * Initialize the console only if we are running as an interactive
     * application.
     */

#ifdef UNDER_CE
    consoleRequired = FALSE;
#endif

    if (consoleRequired) {
	if (Tk_CreateConsoleWindow(interp) == TCL_ERROR) {
	    goto error;
	}
    }
#if defined(STATIC_BUILD) && defined(TCL_USE_STATIC_PACKAGES)
    {
	extern Tcl_PackageInitProc Registry_Init;
	extern Tcl_PackageInitProc Dde_Init;

	if (Registry_Init(interp) == TCL_ERROR) {
	    return TCL_ERROR;
	}
	Tcl_StaticPackage(interp, "registry", Registry_Init, NULL);

	if (Dde_Init(interp) == TCL_ERROR) {
	    return TCL_ERROR;
	}
	Tcl_StaticPackage(interp, "dde", Dde_Init, NULL);
   }
#endif

    Tcl_SetVar(interp, "tcl_rcFileName", "~/wishrc.tcl", TCL_GLOBAL_ONLY);
    return TCL_OK;

error:
    MessageBeep(MB_ICONEXCLAMATION);
    MessageBox(NULL, Tcl_GetStringResult(interp), "Error in Wish",
	    MB_ICONSTOP | MB_OK | MB_TASKMODAL | MB_SETFOREGROUND);
    ExitProcess(1);
    /* we won't reach this, but we need the return */
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * WishPanic --
 *
 *	Display a message and exit.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Exits the program.
 *
 *----------------------------------------------------------------------
 */

void
WishPanic TCL_VARARGS_DEF(CONST char *,arg1)
{
    va_list argList;
    char buf[1024];
    CONST char *format;
    
    format = TCL_VARARGS_START(CONST char *,arg1,argList);
    vsprintf(buf, format, argList);

    MessageBeep(MB_ICONEXCLAMATION);
    MessageBox(NULL, buf, "Fatal Error in Wish",
	    MB_ICONSTOP | MB_OK | MB_TASKMODAL | MB_SETFOREGROUND);
#ifdef _MSC_VER
    DebugBreak();
#endif
    ExitProcess(1);
}
/*
 *-------------------------------------------------------------------------
 *
 * setargv --
 *
 *	Parse the Windows command line string into argc/argv.  Done here
 *	because we don't trust the builtin argument parser in crt0.  
 *	Windows applications are responsible for breaking their command
 *	line into arguments.
 *
 *	2N backslashes + quote -> N backslashes + begin quoted string
 *	2N + 1 backslashes + quote -> literal
 *	N backslashes + non-quote -> literal
 *	quote + quote in a quoted string -> single quote
 *	quote + quote not in quoted string -> empty string
 *	quote -> begin quoted string
 *
 * Results:
 *	Fills argcPtr with the number of arguments and argvPtr with the
 *	array of arguments.
 *
 * Side effects:
 *	Memory allocated.
 *
 *--------------------------------------------------------------------------
 */

static void
setargv(argcPtr, argvPtr)
    int *argcPtr;		/* Filled with number of argument strings. */
    char ***argvPtr;		/* Filled with argument strings (malloc'd). */
{
    char *cmdLine, *p, *arg, *argSpace;
    char **argv;
    int argc, size, inquote, copy, slashes;
    
    cmdLine = GetCommandLine();	/* INTL: BUG */

    /*
     * Precompute an overly pessimistic guess at the number of arguments
     * in the command line by counting non-space spans.
     */

    size = 2;
    for (p = cmdLine; *p != '\0'; p++) {
	if ((*p == ' ') || (*p == '\t')) {	/* INTL: ISO space. */
	    size++;
	    while ((*p == ' ') || (*p == '\t')) { /* INTL: ISO space. */
		p++;
	    }
	    if (*p == '\0') {
		break;
	    }
	}
    }
    argSpace = (char *) Tcl_Alloc(
	    (unsigned) (size * sizeof(char *) + strlen(cmdLine) + 1));
    argv = (char **) argSpace;
    argSpace += size * sizeof(char *);
    size--;

    p = cmdLine;
    for (argc = 0; argc < size; argc++) {
	argv[argc] = arg = argSpace;
	while ((*p == ' ') || (*p == '\t')) {	/* INTL: ISO space. */
	    p++;
	}
	if (*p == '\0') {
	    break;
	}

	inquote = 0;
	slashes = 0;
	while (1) {
	    copy = 1;
	    while (*p == '\\') {
		slashes++;
		p++;
	    }
	    if (*p == '"') {
		if ((slashes & 1) == 0) {
		    copy = 0;
		    if ((inquote) && (p[1] == '"')) {
			p++;
			copy = 1;
		    } else {
			inquote = !inquote;
		    }
                }
                slashes >>= 1;
            }

            while (slashes) {
		*arg = '\\';
		arg++;
		slashes--;
	    }

	    if ((*p == '\0')
		    || (!inquote && ((*p == ' ') || (*p == '\t')))) { /* INTL: ISO space. */
		break;
	    }
	    if (copy != 0) {
		*arg = *p;
		arg++;
	    }
	    p++;
        }
	*arg = '\0';
	argSpace = arg + 1;
    }
    argv[argc] = NULL;

    *argcPtr = argc;
    *argvPtr = argv;
}
#endif
