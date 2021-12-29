#!/usr/bin/env bash

# Download the binutils and set the BINUTILS_TAR variable.
# Args:
#   $1 - version
download_binutils() {
   local file url
   file="binutils-$1.tar.gz"
   url="https://ftp.gnu.org/gnu/binutils/${file}"
   BINUTILS_TAR="${TOP}/sources/${file}"

   download "${BINUTILS_TAR}" "${url}"
}

# Build the GNU binutils.
# Args:
#   $1 - prefix
#   $2 - target arch
build_cross_binutils() {
   local DESTDIR builddir
   builddir="build/binutils-${BINUTILS_VERSION}"

   log "Building the cross-binutils..."
   indent_log +1

   mkdir -p "$1" build

   if [[ ! -d ${builddir} ]]; then
      log "Extracting the tar-ball..."
      check tar -C build -xf "${BINUTILS_TAR}"
   fi
   
   mkdir "${builddir}/build"
   pushd "${builddir}/build"
      # Configure binutils.
      log "Configuring..."
      qcheck ../configure              \
         --prefix="$1"                 \
         --host="$(gcc -dumpmachine)"  \
         --target="$2"                 \
         --with-sysroot="${SYSROOT}"   \
         --disable-nls                 \
         --disable-multilib            \
         --disable-werror

      # Build binutils.
      log "Building..."
      qcheck make -j$(nproc)

      # Install binutils.
      log "Installing..."
      qcheck make install
   popd

   indent_log -1
}
