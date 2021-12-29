#!/usr/bin/env bash

# Download man-pages and set the MAN_PAGES_TAR variable.
# Args:
#   $1 - version
download_man_pages() {
   local file url
   file="man-pages-$1.tar.xz"
   url="https://www.kernel.org/pub/linux/docs/man-pages/${file}"
   MAN_PAGES_TAR="${TOP}/sources/${file}"

   if [[ ! -f $MAN_PAGES_TAR ]]; then
      log "Downloading man-pages..."
      download "${MAN_PAGES_TAR}" "${url}"
   fi
}

build_host_man_pages() {
   local builddir
   builddir="build/man-pages-${MAN_PAGES_VERSION}"

   log "Building man-pages..."
   indent_log +1

   if [[ ! -d ${builddir} ]]; then
      log "Extracting..."
      check tar -C build -xf "$MAN_PAGES_TAR"
   fi

   mkdir -p "${builddir}/build"
   pushd "${builddir}"
      log "Installing..."
      qcheck make prefix="$SYSROOT/usr" install
   popd

   indent_log -1
}
