#ifndef KITSH_NEED_WINMAIN
#include <tcl.h>

int TclKit_AppInit(Tcl_Interp *interp);

int main(int argc, char **argv) {
	Tcl_Main(argc, argv, TclKit_AppInit);

	/* If Tcl_Main() returns, something went wrong */
	return(1);
}
#endif
