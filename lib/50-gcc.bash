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

download_gmp() {
   local file url
   file="gmp-$1.tar.xz"
   url="https://ftp.gnu.org/gnu/gmp/${file}"
   GMP_TAR="${TOP}/sources/${file}"

   if [[ ! -f $GMP_TAR ]]; then
      log "Downloading gmp..."
      download "${GMP_TAR}" "${url}"
   fi
}

download_mpc() {
   local file url
   file="mpc-$1.tar.gz"
   url="https://ftp.gnu.org/gnu/mpc/${file}"
   MPC_TAR="${TOP}/sources/${file}"

   if [[ ! -f $MPC_TAR ]]; then
      log "Downloading mpc..."
      download "${MPC_TAR}" "${url}"
   fi
}

download_mpfr() {
   local file url
   file="mpfr-$1.tar.xz"
   url="https://ftp.gnu.org/gnu/mpfr/${file}"
   MPFR_TAR="${TOP}/sources/${file}"

   if [[ ! -f $MPFR_TAR ]]; then
      log "Downloading mpfr..."
      download "${MPFR_TAR}" "${url}"
   fi
}

create_flags() {
   flags=()
   [[ $WITH_ARCH ]] && flags+=("--with-arch=$WITH_ARCH")
   [[ $WITH_CPU  ]] && flags+=("--with-cpu=$WITH_CPU")
}

gcc_unpack_runtime() {
   pushd "$1"
      [[ -d gmp && -d mpc && -d mpfr ]] && popd && return 0
      log "Unpacking the runtime dependencies..."
      [[ ! -d gmp ]] && check tar -xf "$GMP_TAR" && check mv "gmp-$GMP_VERSION" "gmp"
      [[ ! -d mpc ]] && check tar -xf "$MPC_TAR" && check mv "mpc-$MPC_VERSION" "mpc"
      [[ ! -d mpfr ]] && check tar -xf "$MPFR_TAR" && check mv "mpfr-$MPFR_VERSION" "mpfr"
   popd
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
      log "Extracting..."
      check tar -C build -xf "${GCC_TAR}"
   fi
   
   gcc_unpack_runtime "$builddir"

   rm -rf "${builddir}/build"

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
         --disable-bootstrap           \
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
   
   gcc_unpack_runtime "$builddir"

   pushd "${builddir}/build"
      log "Configuring..."
      qcheck ../configure              \
         --prefix="$TOOLS"             \
         --host="${BUILD}"             \
         --target="$TARGET"            \
         --with-sysroot="${SYSROOT}"   \
         --disable-nls                 \
         --disable-shared              \
         --disable-multilib            \
         --disable-libsanitizer        \
         --enable-languages=c,c++      \
         --disable-libstdcxx-pch       \
         --disable-bootstrap           \
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
   
   gcc_unpack_runtime "$builddir"

   log "Cleaning up..."
   rm -rf "${builddir}/build"

   mkdir "${builddir}/build"
   pushd "${builddir}/build"
      log "Configuring..."
      qcheck ../configure                    \
         CC_FOR_TARGET="${CROSS}gcc"         \
         --prefix="/usr"                     \
         --build="$BUILD"                    \
         --target="$TARGET"                  \
         --host="$TARGET"                    \
         --program-prefix=                   \
         --with-build-sysroot="$SYSROOT"     \
         --disable-nls                       \
         --disable-multilib                  \
         --disable-libatomic                 \
         --disable-libgomp                   \
         --disable-libquadmath               \
         --disable-libssp                    \
         --disable-libvtv                    \
         --disable-libstdcxx                 \
         --disable-bootstrap                 \
         --enable-languages=c,c++            \
         "${flags[@]}"


      log "Building..."
      qcheck pmake

      log "Installing..."
      qcheck make DESTDIR="$SYSROOT" install
      check ln -sf gcc "$SYSROOT/usr/bin/cc"

      if [[ $ENABLE_MINIPKG = 1 ]]; then
         mkdir -p tmp-install
         qcheck make DESTDIR="$PWD/tmp-install" install
         minipkg_add "gcc" "$GCC_VERSION-stage1" tmp-install
      else
         check cp "$GCC_TAR" "$SYSROOT/usr/src/"
      fi
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

