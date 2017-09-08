#! /usr/bin/env bash

# BuildCompatible: KitCreator

pkg='dbif'
version="1.0"
url="http://sourceforge.net/projects/dbus-tcl/files/dbif/${version}/dbif-${version}.tar.gz"
sha256='50d1eed6284d1db168011d16d36ed4724109a0cff73bee16c436aa604893db24'

function preconfigure() {
	make_extra=(moduledir="${installdir}/lib/tcl8/8.5")
}
