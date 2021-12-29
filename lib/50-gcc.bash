#!/usr/bin/env bash

# Download gcc and set the GCC_TAR variable.
# Args:
#   $1 - version
download_gcc() {
   local file url
   file="gcc-$1.tar.gz"
   url="https://ftp.gnu.org/gnu/gcc/gcc-$1/${file}"
   GCC_TAR="${TOP}/sources/${file}"

   if [[ ! -f $GCC_TAR ]]; then
      log "Downloading gcc..."
      download "${GCC_TAR}" "${url}"
   fi
}

create_flags() {
   flags=()
   [[ $WITH_ARCH ]] && flags+=("--with-arch=$WITH_ARCH")
   [[ $WITH_CPU  ]] && flags+=("--with-cpu=$WITH_CPU")
}

# Build the stage-1 compiler.
build_cross_gcc_stage1() {
   local builddir
   local -a flags
   builddir="${TOP}/build/gcc-${GCC_VERSION}"

   create_flags

   log "Building the stage 1 cross-compiler..."
   indent_log +1

   mkdir -p "$TOOLS" build

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
         --prefix="$TOOLS"             \
         --host="${BUILD}"        \
         --target="$TARGET"            \
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
         --enable-languages=c          \
         "${flags[@]}"

      log "Building..."
      qcheck make -j$(nproc)

      log "Installing..."
      qcheck make install

   popd
   indent_log -1
}

build_cross_gcc() {
   local builddir
   local -a flags
   builddir="${TOP}/build/gcc-${GCC_VERSION}"

   create_flags

   log "Building the final cross-compiler..."
   indent_log +1

   [[ -d ${builddir} ]] || fail "${builddir} is not present."
   

   pushd "${builddir}/build"
      log "Configuring..."
      qcheck ../configure              \
         --prefix="$TOOLS"             \
         --host="${BUILD}"        \
         --target="$TARGET"            \
         --with-sysroot="${SYSROOT}"   \
         --disable-nls                 \
         --disable-shared              \
         --disable-multilib            \
         --disable-libsanitizer        \
         --enable-languages=c,c++      \
         "${flags[@]}"

      log "Building..."
      qcheck pmake

      log "Installing..."
      qcheck make install

   popd
   indent_log -1
}

build_host_gcc() {
   local builddir
   local -a flags
   builddir="${TOP}/build/gcc-${GCC_VERSION}"

   create_flags

   log "Building the compiler..."
   indent_log +1

   if [[ ! -d ${builddir} ]]; then
      log "Extracting..."
      tar -C build -xf "${GCC_TAR}"
   fi
   
   pushd "${builddir}"
      log "Downloading the compiler runtime..."
      qcheck ./contrib/download_prerequisites
   popd

   log "Cleaning up..."
   rm -rf "${builddir}/build"

   mkdir "${builddir}/build"
   pushd "${builddir}/build"
      log "Configuring..."
      qcheck ../configure                 \
         --prefix="$TOOLS"                \
         --build="$BUILD"                 \
         --host="$TARGET"                 \
         --with-build-sysroot="$SYSROOT"  \
         --disable-nls                    \
         --disable-shared                 \
         --disable-multilib               \
         --disable-libatomic              \
         --disable-libgomp                \
         --disable-libquadmath            \
         --disable-libvtv                 \
         --disable-libsanitizer           \
         --enable-languages=c,c++         \
         "${flags[@]}"

      log "Building..."
      qcheck pmake

      log "Installing..."
      qcheck make DESTDIR="$SYSROOT" install
      check ln -s gcc "$SYSROOT/usr/bin/cc"
   popd
   indent_log -1
}

# This check if the cross-compiler can make binaries.
check_cross_gcc() {
   log "Checking the cross-compiler..."
   echo -e '#include<stdio.h>\nint main() { puts("Hello World"); }' >build/test.c
   qcheck "${TARGET}-gcc" build/test.c -o build/test
   rm -f build/test
}

