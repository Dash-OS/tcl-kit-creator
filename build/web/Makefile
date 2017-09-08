STARKIT2EXE = ../../../starkit2exe/starkit2exe
RIVET2STARKIT = ../../../rivet/bin/rivet2starkit
WEBDIR = /web/customers/kitcreator.rkeene.org
WEBKITSDIR = $(WEBDIR)/kits

kitcreator.cgi: kitcreator.kit
	$(STARKIT2EXE) kitcreator.kit kitcreator.cgi

kitcreator.kit: kitcreator.vfs kitcreator.vfs/index.rvt
	$(RIVET2STARKIT) tclkit kitcreator.kit kitcreator.vfs

install: kitcreator.cgi building.cgi
	mkdir -p '$(WEBDIR)' '$(WEBKITSDIR)'
	cp kitcreator.cgi '$(WEBDIR)/'
	cp building.cgi '$(WEBKITSDIR)/'
	echo -n > '${WEBKITSDIR}/index.html'

clean:
	rm -f kitcreator.kit kitcreator.cgi

distclean: clean

.PHONY: clean distclean install
