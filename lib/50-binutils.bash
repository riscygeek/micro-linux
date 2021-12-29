#!/usr/bin/env bash

# Download the binutils and set the BINUTILS_TAR variable.
# Args:
#   $1 - version
download_binutils() {
   local file url
   file="binutils-$1.tar.gz"
   url="https://ftp.gnu.org/gnu/binutils/${file}"
   BINUTILS_TAR="${TOP}/sources/${file}"

   if [[ ! -f $BINUTILS_TAR ]]; then
      log "Downloading binutils..."
      download "${BINUTILS_TAR}" "${url}"
   fi
}

# Build the GNU binutils.
build_cross_binutils() {
   local builddir
   builddir="build/binutils-${BINUTILS_VERSION}"

   log "Building the cross-binutils..."
   indent_log +1

   mkdir -p "${TOOLS}" build

   if [[ ! -d ${builddir} ]]; then
      log "Extracting..."
      check tar -C build -xf "${BINUTILS_TAR}"
   fi
   
   mkdir -p "${builddir}/build"
   pushd "${builddir}/build"
      # Configure binutils.
      log "Configuring..."
      qcheck ../configure              \
         --prefix="${TOOLS}"           \
         --host="${BUILD}"        \
         --target="${TARGET}"          \
         --with-sysroot="${SYSROOT}"   \
         --disable-nls                 \
         --disable-multilib            \
         --disable-werror

      # Build binutils.
      log "Building..."
      qcheck pmake

      # Install binutils.
      log "Installing..."
      qcheck make install
   popd

   indent_log -1
}

build_host_binutils() {
   local builddir
   builddir="build/binutils-${BINUTILS_VERSION}"

   log "Building the binutils..."
   indent_log +1

   if [[ ! -d ${builddir} ]]; then
      log "Extracting..."
      check tar -C build -xf "$BINUTILS_TAR"
   fi
   log "Cleaning up..."
   rm -rf "${builddir}/build"

   mkdir "${builddir}/build"
   pushd "${builddir}/build"
      log "Configuring..."
      qcheck ../configure                 \
         --prefix=/usr                    \
         --build="$BUILD"                 \
         --host="$TARGET"                 \
         --disable-nls                    \
         --disable-multilib               \
         --disable-werror

      log "Building..."
      qcheck pmake

      log "Installing..."
      qcheck make DESTDIR="$SYSROOT" install
      #install -m755 libctf/.libs/libctf.so.0.0.0 "$SYSROOT/usr/lib"
   popd

   indent_log -1
}
