#!/usr/bin/env bash

# Download gcc and set the GCC_TAR variable.
# Args:
#   $1 - version
download_gcc() {
   local file url
   file="gcc-$1.tar.gz"
   url="https://ftp.gnu.org/gnu/gcc/gcc-$1/${file}"
   GCC_TAR="${TOP}/sources/${file}"

   download "${GCC_TAR}" "${url}"
}


# Build the stage-1 compiler.
# Args:
#   $1 - prefix
#   $2 - target arch
build_cross_gcc_stage1() {
   local DESTDIR builddir
   builddir="${TOP}/build/gcc-${GCC_VERSION}"

   log "Building the cross-compiler..."
   indent_log +1

   # Determine the `DESTDIR` variable.
   mkdir -p "$1" build

   if [[ ! -d ${builddir} ]]; then
      log "Extracting the compiler..."
      check tar -C build -xf "${GCC_TAR}"
   fi
   
   pushd "${builddir}"
      log "Downloading the compiler runtime..."
      qcheck ./contrib/download_prerequisites
   popd

   mkdir "${builddir}/build"
   pushd "${builddir}/build"
      log "Configuring..."
      qcheck ../configure              \
         --prefix="$1"                 \
         --host="$(gcc -dumpmachine)"  \
         --target="$2"                 \
         --with-sysroot="${SYSROOT}"   \
         --with-newlib                 \
         --without-headers             \
         --enable-initfini-array       \
         --disable-nls                 \
         --disable-shared              \
         --disable-multilib            \
         --disable-decimal-float       \
         --disable-threads             \
         --disable-libatomic           \
         --disable-libgomp             \
         --disable-libquadmath         \
         --disable-libssp              \
         --disable-libvtv              \
         --disable-libstdcxx           \
         --enable-languages=c,c++

      log "Building..."
      qcheck make -j$(nproc)

      log "Installing..."
      qcheck make install

   popd
}
