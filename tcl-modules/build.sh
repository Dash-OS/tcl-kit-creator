# BuildCompatible: KitCreator

# adds tcl-modules
# [package require tcl-modules]
#   - once this is done then you can require
#     any of the tcl modules that are included

url_prefix="https://github.com/Dash-OS/tcl-modules"

pkg_name="tcl-modules"

### The version we want to build.  This should match
### a release available in the repo releases.
### ${url_prefix}/releases
### -- This package changes constantly, checking releases
###    on every build is adviseable.
version='2.090717.76';

### Install the release specified above and
### verify the sha256 signature.
### https://hash.online-convert.com/sha256-generator
url="${url_prefix}/archive/${version}.tar.gz"
sha256='-'

### If we want to use master
# url="https://github.com/Dash-OS/tcl-parser/archive/master.tar.gz"
# sha256='-'

if [ -d "./out" ]; then
  rm -rf "./out"
fi

OUTDIR="$(pwd)/out"
OUTLIBDIR="${OUTDIR}/lib/tcl-modules"

function postdownload() {
  # add tcl-cluster https://github.com/Dash-OS/tcl-cluster
  downloadTclCluster
  # add tcl-task-manager https://github.com/Dash-OS/tcl-task-manager
  downloadTclTask
}

function downloadTclCluster() {
  # tcl-cluster
  cluster_version="2.090617.71"
  cluster_archive_name="tcl-cluster-${cluster_version}"
  cluster_url="https://github.com/Dash-OS/tcl-cluster/archive/${cluster_version}.tar.gz"
  cluster_archive="${archivedir}/${cluster_archive_name}.tar.gz"
  if [ ! -e "${cluster_archive}" ]; then
    "${_download}" "${cluster_url}" "${cluster_archive}" "-" || return 1
  fi
}

function downloadTclTask() {
  # tcl-task-manager
  task_version="2.090417.31"
  task_archive_name="tcl-task-manager-${task_version}"
  task_url="https://github.com/Dash-OS/tcl-task-manager/archive/${task_version}.tar.gz"
  task_archive="${archivedir}/${task_archive_name}.tar.gz"
  if [ ! -e "${task_archive}" ]; then
    "${_download}" "${task_url}" "${task_archive}" "-" || return 1
  fi
}

function preconfigure() {
  mkdir -p "${OUTLIBDIR}"

  if [ -d "${cluster_archive_name}" ]; then
    cp -rf "${cluster_archive_name}"/* "${OUTLIBDIR}/"
    rm -rf "${cluster_archive_name}"
  fi

  if [ -d "${task_archive_name}" ]; then
    cp -rf "${task_archive_name}"/* "${OUTLIBDIR}/"
    rm -rf "${task_archive_name}"
  fi

  cp -rf ./* "${OUTLIBDIR}/"

  rm -rf \
    "${OUTLIBDIR}/tcl-modules" \
    "${OUTLIBDIR}"/.* \
    "${OUTLIBDIR}"/*.md \
    "${OUTLIBDIR}"/LICENSE \

  exit 0
}
