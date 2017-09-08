#! /usr/bin/env bash
# BuildCompatible: KitCreator

pkg='tcl-signal'

url_prefix="https://github.com/Dash-OS/${pkg}"

### The version we want to build.  This should match
### a release available in the repo releases.
### ${url_prefix}/releases
version='1.5.1'

### If the tcl package has a different version than the
### one we use to download the release archive
### Defaults to $version if not defined
#pkg_version="${version}"

### The name of the package
pkg_name="signal"

### The name of the tclpkglib that should be loaded.
### Used when we call load {} $tclpkglib.
### Defaults to $pkg_name if not defined
#pkg_lib_name="${pkg_name}"

### override user / force build static
#pkg_always_static='1'

### Install the release specified above and
### verify the sha256 signature.
### https://hash.online-convert.com/sha256-generator
url="${url_prefix}/archive/${version}.tar.gz"
sha256='e292a7b7601ab25dda553385a95a33aade02c4279a2a3779b6fe236a1b13c096'

### If we want to use master
# url="${url_prefix}/archive/master.tar.gz"
# sha256='-'
