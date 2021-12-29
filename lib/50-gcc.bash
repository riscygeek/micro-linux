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
#   $2 - DESTDIR
#   $3 - host arch
#   $4 - target arch
build_gcc_stage1() {
   local DESTDIR builddir

   # Determine the `DESTDIR` variable.
   [[ $2 ]] && DESTDIR="$2" || DESTDIR="$1"

   # Determine the build directory.
   [[ $3 = $4 ]] && builddir="${TOP}/build/gcc" || builddi="${TOP}/build/cross-gcc"

   mkdir -p build
   tar -C "${builddir}" -xf "${TOP}/sources/${GCC_TAR}"

   mkdir "${builddir}/build"
   pushd "${builddir}/build"
      # Configure gcc.
      ../configure --prefix="$1" --host="$3" --target="$4"     \
         --disable-nls --disable-multilib --enable-languages=c \
         --without-headers

      # Build gcc.
   popd
}
