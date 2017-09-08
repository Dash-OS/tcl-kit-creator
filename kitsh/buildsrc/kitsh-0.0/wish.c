#include <tk.h>

int Tcl_AppInit(Tcl_Interp *interp) {
	int tcl_ret;

	tcl_ret = Tcl_Init(interp);
	if (tcl_ret == TCL_ERROR) {
		return(tcl_ret);
	}

	tcl_ret = Tk_Init(interp);
	if (tcl_ret == TCL_ERROR) {
		return(tcl_ret);
	}

#ifdef _WIN32
	tcl_ret = Tk_CreateConsoleWindow(interp);
	if (tcl_ret == TCL_ERROR) {
		return(tcl_ret);
	}
#endif

	return(TCL_OK);
}

int main(int argc, char **argv) {
	Tk_Main(argc, argv, Tcl_AppInit);

	return(1);
}
