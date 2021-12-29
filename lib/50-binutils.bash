
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
#   $2 - DESTDIR
#   $3 - host arch
#   $4 - target arch
build_binutils() {
   local DESTDIR builddir

   # Determine the `DESTDIR` variable.
   [[ $2 ]] && DESTDIR="$2" || DESTDIR="$1"

   # Determine the build directory.
   [[ $3 = $4 ]] && builddir="${TOP}/build/binutils" || builddi="${TOP}/build/cross-binutils"

   mkdir -p build
   tar -C "${builddir}" -xf "${TOP}/sources/${BINUTILS_TAR}"
   
   mkdir "${builddir}/build"
   pushd "${builddir}/build"
      # Configure binutils.
      ../configure --prefix="$1" --host="$3" --target="$4" --disable-nls --disable-multilib

      # Build binutils.
      make -j$(nproc)

      # Install binutils.
      make DESTDIR="${DESTDIR}" install
   popd
}
