# Example build script
# with some options to change
#
### Run this first!
# utils/pre.sh

#### Clean the Kitcreator Libs and Archives
# ./kitcreator distclean
### Clean the Kitcreator Libs but keep the Archives
# ./kitcreator clean

export KITCREATOR_PKGS="tcl-modules tcc4tcl tuapi socketserver signal tclparser tdom yajltcl rl_json udp mk4tcl tcllib unix_sockets tls";

KC_PATH=$(pwd)

export KC_TLS_LINKSSLSTATIC="1";
export KC_TLS_BUILDSSL="1";
export KC_TCL_STATICPKGS="1";
# export STATICTLS='1';
# export STATICRL_JSON='1';
# export STATICTDOM="1";
# export STATICUDP="1";
# export STATICTUAPI="1";
# export STATICMK4TCL="1";
# export STATICZLIB="1";
# export STATICUNIX_SOCKETS="1";
# export STATICTCC4TCL="1";
# export STATICTCLPARSER="1";

export LDFLAGS="-lrt"

############################################
### Extra Arguments to give kitcreator
KC_EXTRA_ARGS=""

### What version of Tcl should be used?
## If this is left empty, 8.6.7 will be used.
# Fixes bug with cross-compiling for older gcc versions
KITCREATOR_TCL_VERSION="fossil_core-8-6-branch"

#### Choose kit storage
### cvfs
KITCREATOR_STORAGE='cvfs'
### mk4tcl
# KITCREATOR_STROAGE='mk4'
### zip
# KITCREATOR_STORAGE='zip'
### auto
# KITCREATOR_STORAGE='auto'

#### Obsfucate the kit?
KC_EXTRA_ARGS="${KC_EXTRA_ARGS} --with-obsfucated-cvfs"

#### Custom kit.rc
### If desired, you may specify a custom kit.rc file
### that will be used.  See ./kitsh/buildsrc/kitsh-0.0/kit.rc
# export KITCREATOR_RC=''

#### Custom Icon
### Specify a custom .ico file to use if desired
export KITCREATOR_ICON="${KC_PATH}/assets/kit.ico"

#### Custom Boot File
### If you want to run preliminary code whenever
### the kit is started, you may put any scripts
### within the assets/boot folder.  All included
### tcl scripts will be sourced on startup by
### conducting a [glob -directory assets/boot *.tcl]

#### Configure Extra
### Specify extra parameters to pass to all configure
### scripts if needed
# CONFIGUREXTRA=''

# ./kitcreator \
#   --enable-kit-storage="${KITCREATOR_STORAGE}" \
#   $KC_EXTRA_ARGS

./kitcreator retry \
  --enable-kit-storage="${KITCREATOR_STORAGE}" \
  $KC_EXTRA_ARGS

# {
#   "common": {
#     "tcl": {
#       "version": "fossil_core-8-6-branch"
#     },
#     "packages": [
#       ["tcl-modules", {
#         "boot": true,
#         "version": "1.9.0"
#       }],
#       ["tcllib", {
#         "version": "1.18"
#       }],
#       "udp",
#       "tls",
#       "tdom",
#       "tuapi",
#       "mk4tcl",
#       "yajltcl",
#       "rl_json",
#       "tcc4tcl",
#       "signal",
#       "tclparser",
#       "socketserver",
#       "unix_sockets"
#     ]
#   }
#   "builds": [
#     {
#       "host": "arm-none-linux-eabie",
#       "output": "arm/eabi",
#       "bin": "toolchains/arm-none-linux-eabi/bin"
#     }
#   ]
# }
