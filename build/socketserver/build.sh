#! /usr/bin/env bash
# BuildCompatible: KitCreator

pkg="tcl-socketserver"

url_prefix="https://github.com/Dash-OS/${pkg}"

### The version we want to build.  This should match
### a release available in the repo releases.
### ${url_prefix}/releases
version='1.0.1';

### If the tcl package has a different version than the
### one we use to download the release archive
pkg_version="${version}";

### The name of the package
pkg_name='socketserver'

### The name of the tclpkglib that should be loaded.
### Used when we call load {} $tclpkglib.
### Defaults to $pkg_name if not defined
#pkg_lib_name="${pkg_name}"

### override user / force build static
# pkg_always_static='1'

### Install the release specified above and
### verify the sha256 signature.
### https://hash.online-convert.com/sha256-generator
url="${url_prefix}/archive/${version}.tar.gz"
sha256='f34446641083c59897bbe2161dce59588ca2d35215e9c51108e9c3524c87c4b5'

### If we want to use master
# url="${url_prefix}/archive/master.tar.gz"
# sha256='-'
