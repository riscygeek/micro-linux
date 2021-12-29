#!/usr/bin/env bash

# Download make and set the MAKE_TAR variable.
# Args:
#   $1 - version
download_make() {
   local file url
   file="make-$1.tar.gz"
   url="https://ftp.gnu.org/gnu/make/${file}"
   MAKE_TAR="${TOP}/sources/${file}"

   if [[ ! -f $MAKE_TAR ]]; then
      log "Downloading make..."
      download "${MAKE_TAR}" "${url}"
   fi
}

build_host_make() {
   local builddir
   builddir="build/make-${MAKE_VERSION}"

   log "Building make..."
   indent_log +1

   if [[ ! -d ${builddir} ]]; then
      log "Extracting..."
      check tar -C build -xf "$MAKE_TAR"
   fi

   mkdir -p "${builddir}/build"
   pushd "${builddir}/build"
      log "Configuring..."
      qcheck ../configure           \
         --prefix=/usr              \
         --build="$BUILD"           \
         --host="$TARGET"           \
         --without-guile            \
         --disable-nls

      log "Building..."
      qcheck pmake

      log "Installing..."
      qcheck make DESTDIR="$SYSROOT" install
   popd

   indent_log -1
}
