#include <tcl.h>

int Tcl_AppInit(Tcl_Interp *interp) {
	return(Tcl_Init(interp));
}

int main(int argc, char **argv) {
	Tcl_Main(argc, argv, Tcl_AppInit);

	return(1);
}
