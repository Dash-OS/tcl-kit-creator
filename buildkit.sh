# Example build script
# with some options to change
#
### Run this first!
# utils/pre.sh

#### Clean the Kitcreator Libs and Archives
# ./kitcreator distclean
### Clean the Kitcreator Libs but keep the Archives
# ./kitcreator clean


###### BUILD SPECIFIC CONFIGURATION ########

export KC_PATH="${BUILD_DIR}/kitcreator";

export KITCREATOR_PKGS="tcl-modules tuapi socketserver signal tclparser tdom yajltcl rl_json udp tcllib unix_sockets tls";

export KC_TLS_LINKSSLSTATIC="1";
export KC_TLS_BUILDSSL="1";
export KC_TCL_STATICPKGS="1";
export STATICTLS='1';

############################################
### Extra Arguments to give kitcreator
KC_EXTRA_ARGS=""

### What version of Tcl should be used?
## If this is left empty, 8.6.7 will be used.
# Fixes bug with cross-compiling for older gcc versions
export KITCREATOR_TCL_VERSION="fossil_core-8-6-branch"

#### Choose kit storage
### cvfs
export KITCREATOR_STORAGE='cvfs'
### mk4tcl
# KITCREATOR_STROAGE='mk4'
### zip
# KITCREATOR_STORAGE='zip'
### auto
# KITCREATOR_STORAGE='auto'

#### Obsfucate the kit?
# KC_EXTRA_ARGS="${KC_EXTRA_ARGS} --with-obsfucated-cvfs"

#### Custom kit.rc
### If desired, you may specify a custom kit.rc file
### that will be used.  See ./kitsh/buildsrc/kitsh-0.0/kit.rc
# export KITCREATOR_RC=''

#### Custom Icon
### Specify a custom .ico file to use if desired
export KITCREATOR_ICON="${KC_PATH}/assets/kit.ico"

#### Shared Libraries?
## Do you want to build shared libraries?
KC_EXTRA_ARGIS="${KC_EXTRA_ARGS}"

#### Cross Compiling?
## Set the host value to the system being
## built for
KC_EXTRA_ARGS="${KC_EXTRA_ARGS} --host=${chain}"

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

./kitcreator \
  --enable-kit-storage="${KITCREATOR_STORAGE}" \
  $KC_EXTRA_ARGS

# ./kitcreator retry \
#   --enable-kit-storage="${KITCREATOR_STORAGE}" \
#   $KC_EXTRA_ARGS
