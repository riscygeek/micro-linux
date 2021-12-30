#!/usr/bin/env bash

# Download the make and set the BASH_TAR variable.
# Args:
#   $1 - version
download_bash() {
   local file url
   file="bash-$1.tar.gz"
   url="https://ftp.gnu.org/gnu/bash/${file}"
   BASH_TAR="${TOP}/sources/${file}"

   if [[ ! -f $BASH_TAR ]]; then
      log "Downloading bash..."
      download "${BASH_TAR}" "${url}"
   fi
}

build_host_bash() {
   local builddir
   builddir="${TOP}/build/bash-${BASH_VERSION}"

   log "Building bash..."
   indent_log +1

   if [[ ! -d ${builddir} ]]; then
      log "Extracting..."
      check tar -C build -xf "$BASH_TAR"
   fi

   mkdir -p "${builddir}/build"
   pushd "${builddir}/build"
      log "Configuring..."
      qcheck ../configure        \
         --prefix=/usr           \
         --build="$BUILD"        \
         --host="$TARGET"        \
         --without-bash-malloc

      log "Building..."
      qcheck pmake

      log "Installing..."
      qcheck make DESTDIR="$SYSROOT" install

      if [[ $ENABLE_MINIPKG = 1 ]]; then
         mkdir -p tmp-install
         qcheck make DESTDIR="$PWD/tmp-install" install
         minipkg_add "bash" "$BASH_VERSION" tmp-install
      fi
   popd
   indent_log -1
}
