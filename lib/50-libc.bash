#!/usr/bin/env bash

# Download the make and set the MAKE_TAR variable.
# Args:
#   $1 - version
download_glibc() {
   local file url
   file="glibc-${GLIBC_VERSION}.tar.gz"
   url="https://ftp.gnu.org/gnu/glibc/${file}"
   LIBC_TAR="${TOP}/sources/${file}"

   if [[ ! -f $LIBC_TAR ]]; then
      log "Downloading glibc..."
      download "${LIBC_TAR}" "${url}"
   fi
}

download_musl() {
   local file url
   file="musl-${MUSL_VERSION}.tar.gz"
   url="https://musl.libc.org/releases/${file}"
   LIBC_TAR="${TOP}/sources/${file}"

   if [[ ! -f ${LIBC_TAR} ]]; then
      log "Downloading musl libc..."
      download "${LIBC_TAR}" "${url}"
   fi
}

download_libc() {
   eval "download_${LIBC_NAME}"
}

# Args:
#   $1 - machine
#   $2 - 1 if `LIBC_VERSION` has to be set.
set_libc() {
   case "$1" in
   *-gnu*)
      LIBC_NAME="glibc"
      [[ $LIBC_VERSION ]] || LIBC_VERSION="$GLIBC_VERSION"
      ;;
   *-musl*)
      LIBC_NAME="musl"
      [[ $LIBC_VERSION ]] || LIBC_VERSION="$MUSL_VERSION"
      ;;
   *)
      fail "Failed to determine C library. See set_libc() in lib/50-libc.bash."
      ;;
   esac
}


build_musl() {
   local builddir DESTDIR
   builddir="build/musl-${LIBC_VERSION}"

   log "Building the C library (musl)..."
   indent_log +1

   # Clean old directories.
   rm -rf "${builddir}"

   log "Extracting..."
   check tar -C build -xf "${LIBC_TAR}"

   pushd "${builddir}"
      log "Configuring..."
      qcheck ./configure \
         CROSS_COMPILE="${TARGET}-"    \
         --prefix=/usr                 \
         --target="${TARGET}"

      log "Building..."
      qcheck pmake

      log "Installing..."
      DESTDIR="${SYSROOT}" qcheck make install

      if [[ $ENABLE_MINIPKG = 1 ]]; then
         mkdir -p tmp-install
         DESTDIR="$PWD/tmp-install" qcheck make install
         minipkg_add "musl" "$LIBC_VERSION" tmp-install
      fi
   popd

   indent_log -1
}

build_glibc() {
   #fail "Building glibc is not yet supported! See: lib/50-libc.bash"
   local builddir DESTDIR
   builddir="build/glibc-${LIBC_VERSION}"

   log "Building the C library (glibc)..."
   indent_log +1

   if [[ ! -d ${builddir} ]]; then
      log "Extracting..."
      check tar -C build -xf "${LIBC_TAR}"
   fi

   mkdir -p "${builddir}/build"
   pushd "${builddir}/build"
      log "Configuring..."
      echo "rootsbindir=/usr/sbin" > configparms
      qcheck ../configure                          \
         --prefix=/usr                             \
         --host="${BUILD}"                         \
         --build="${BUILD}"                        \
         --with-headers="${SYSROOT}/usr/include"   \
         --enable-kernel=3.2                       \
         --disable-multilib                        \
         libc_cv_slibdir=/usr/lib

      log "Building..."
      qcheck pmake

      log "Installing..."
      qcheck make DESTDIR="$SYSROOT" install

      if [[ $ENABLE_MINIPKG = 1 ]]; then
         mkdir -p tmp-install
         qcheck make DESTDIR="$PWD/tmp-install" install
         minipkg_add "glibc" "$LIBC_VERSION" tmp-install
      fi

      # Fix from https://linuxfromscratch.org/lfs/view/stable/chapter05/glibc.html
      sed -i '/RTLDLIST=/s@/usr@@g' "$SYSROOT/usr/bin/ldd"
   popd
   indent_log -1
}

build_libc() {
   eval "build_${LIBC_NAME}"
}
