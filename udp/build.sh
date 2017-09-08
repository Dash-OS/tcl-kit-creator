#! /usr/bin/env bash
# BuildCompatible: KitCreator

# package / repo name, should match the repo / archive name
pkg='tcludp'

url_prefix="http://sourceforge.net/projects/tcludp/files/tcludp"

### The version we want to build.  This should match
### a release available in the repo releases.
### ${url_prefix}/releases
version='1.0.11';

### If the tcl package has a different version than the
### one we use to download the release archive
pkg_version="${version}";

### The name of the package [package require $pkg_name]
pkg_name='udp'

### The name of the tclpkglib that should be loaded.
### Used when we call load {} $pkg_lib_name
### Defaults to $pkg_name if not defined
#pkg_lib_name="${pkg_name}"

### override user / force build static
# pkg_always_static='1'

### any extra flags for configure
configure_extra=(ac_cv_path_DTPLITE=no)

### Install the release specified above and
### verify the sha256 signature.
### https://hash.online-convert.com/sha256-generator
url="${url_prefix}/${version}/tcludp-${version}.tar.gz"
sha256='a8a29d55a718eb90aada643841b3e0715216d27cea2e2df243e184edb780aa9d'

### If we want to use master
# url="https://github.com/Dash-OS/tcl-parser/archive/master.tar.gz"
# sha256='-'
