#! /usr/bin/env bash
# BuildCompatible: KitCreator

url_prefix="https://github.com/RubyLane/rl_json"

### The version we want to build.  This should match
### a release available in the repo releases.
### ${url_prefix}/releases
version='0.9.11'

### If the tcl package has a different version than the
### one we use to download the release archive
### Defaults to $version if not defined
#pkg_version="${version}"

### The name of the package
pkg_name="rl_json"

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
sha256='591152a7b83027023f7cad6dfd333eabbe28d358ba62162d21550c95b424893d'

### If we want to use master
# url="${url_prefix}/archive/master.tar.gz"
# sha256='-'
