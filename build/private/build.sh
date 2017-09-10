# BuildCompatible: KitCreator

# Used to add custom / private scripts to the
# kit.  These scripts will be obsfucated within
# cvfs (and should use cvfs as the storage system).
#
# This allows us to only obsfucate the specific scripts
# which may be private and/or should be obsfucated
# without doing so to our entire kit (which can increase
# the size drastically).

# When added, we will look in the "assets/private" folder
# and add all files within the private folder to our
# cvfs library.

KITSH_DIRECTORY="${PKG_DIRECTORY}/kitsh/buildsrc/kitsh-"?.?
PRIVATE_DIRECTORY="${KC_DIRECTORY}/assets/private"
OUTDIR="$(pwd)/out"

function predownload() {
  if [ ! -d "${PRIVATE_DIRECTORY}" ]; then
    echo "assets/private directory not found"
    exit 1
  fi
  
  if [ -d "${OUTDIR}" ]; then
    rmdir "${OUTDIR}"
  fi

  # if provided, the private directory is required.
  if [ ! -d "${PRIVATE_DIRECTORY}" ]; then
    echo "assets/private is not a directory"
    exit 1
  fi

  mkdir -p "${OUTDIR}/private" || exit 1

  cp -rf "${PRIVATE_DIRECTORY}"/* "${OUTDIR}/private/" || exit 1

  exit 0
}
