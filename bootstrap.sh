#!/usr/bin/env bash

target="x86_64-unknown-linux-musl"
host="$(gcc -dumpmachine)"

fail() { echo "$@" >&2; exit 1; }
has() { which "$1" &>/dev/null; }
check_dep() { has "$1" || fail "'$1' is not installed."; }
download() { [[ -f $2 ]] || wget "$1" "-O" "$2" || { rm -f "$2"; fail "Failed to download '$1'."; }; }
pushd() { builtin pushd "$1" &>/dev/null || exit 1; }
popd() { builtin popd &>/dev/null || exit 1; }
check() { "$@" || fail "Failed to run: $@"; }
checking() { echo -n "Checking $@..."; }
pmake() { make -j"$(nproc)"; }

srcdir="$PWD/src"
builddir="$PWD/build"
rootdir="$PWD/rootfs"
toolsdir="$PWD/tools"

export PATH="$toolsdir:$PATH"

rm -rf "$builddir"
mkdir -p "$srcdir" "$builddir" "$rootdir" || exit 1

# Define package versions.
KERNEL_VERSION="5.15.12"
BUSYBOX_VERSION="1.35.0"
BINUTILS_VERSION="2.37"
GCC_VERSION="11.2.0"
MAKE_VERSION="4.3"
GLIBC_VERSION="2.33"
MUSL_VERSION="1.2.2"
BASH_VERSION="5.1"
MINIPKG2_VERSION="0.1"


[[ $(cut -d. -f1 <<< "$KERNEL_VERSION") -lt 3 ]] && fail "Kernel version must be at least 3.0"

# Define package files.
KERNEL_TAR="linux-${KERNEL_VERSION}.tar.xz"
BUSYBOX_TAR="busybox-${BUSYBOX_VERSION}.tar.bz2"
BINUTILS_TAR="binutils-${BINUTILS_VERSION}.tar.gz"
GCC_TAR="gcc-${GCC_VERSION}.tar.gz"
MAKE_TAR="make-${MAKE_VERSION}.tar.gz"
GLIBC_TAR="glibc-${GLIBC_VERSION}.tar.gz"
MUSL_TAR="musl-${MUSL_VERSION}.tar.gz"
BASH_TAR="bash-${BASH_VERSION}.tar.gz"
MINIPKG2_TAR=""

# Define package URLs.
GNUFTP="https://ftp.gnu.org/gnu"
KERNEL_URL="https://mirrors.edge.kernel.org/pub/linux/kernel/v$(cut -d. -f1 <<<"$KERNEL_VERSION").x/$KERNEL_TAR"
BUSYBOX_URL="https://busybox.net/downloads/$BUSYBOX_TAR"
BINUTILS_URL="$GNUFTP/binutils/$BINUTILS_TAR"
GCC_URL="$GNUFTP/gcc/gcc-${GCC_VERSION}/$GCC_TAR"
MAKE_URL="$GNUFTP/make/$MAKE_TAR"
GLIBC_URL="$GNUFTP/glibc/$GLIBC_TAR"
MUSL_URL="https://musl.libc.org/releases/$MUSL_TAR"
BASH_URL="$GNUFTP/bash/$BASH_TAR"
MINIPKG2_URL=""

echo "Checking dependencies..."
# Check for build dependencies.
check_dep "which"
check_dep "make"
check_dep "wget"
check_dep "gcc"

# Checking the C library.
checking "the C library"
case "$target" in
*-gnu*)
   LIBC="glibc"
   LIBC_VERSION="$GLIBC_VERSION"
   LIBC_URL="$GLIBC_URL"
   LIBC_TAR="$GLIBC_TAR"
   ;;
*-musl*)
   LIBC="musl"
   LIBC_VERSION="$MUSL_VERSION"
   LIBC_URL="$MUSL_URL"
   LIBC_TAR="$MUSL_TAR"
   ;;
*)
   fail "Failed to detect C library for '$target'"
   ;;
esac
echo "$LIBC"

# Checking the procesor arch.
checking "the kernel architecture"
case "$target" in
i[3456]86-*|x86_64-*)
   KARCH="x86"
   ;;
arm-*|armv*-*|aarch64-*)
   KARCH="arm"
   ;;
riscv*-*)
   KARCH="riscv"
   ;;
*)
   fail "Failed to determine kernel architecture for '$target'"
   ;;
esac
echo "$KARCH"

echo "Downloading..."
# Download sources
download "$KERNEL_URL"     "$srcdir/$KERNEL_TAR"
download "$BUSYBOX_URL"    "$srcdir/$BUSYBOX_TAR"
download "$BINUTILS_URL"   "$srcdir/$BINUTILS_TAR"
download "$GCC_URL"        "$srcdir/$GCC_TAR"
download "$MAKE_URL"       "$srcdir/$MAKE_TAR"
download "$LIBC_URL"       "$srcdir/$LIBC_TAR"
download "$BASH_URL"       "$srcdir/$BASH_TAR"
# download "$MINIPKG2_URL"   "$srcdir/$MINIPKG2_TAR"

# Build a cross-compiler if not already built.
if ! has "${target}-gcc"; then
   mkdir -p "$toolsdir"
   pushd "$builddir"
      # Install cross-kernel-headers.
      echo "Installing the cross-kernel-headers..."
      check tar -xf "$srcdir/$KERNEL_TAR"
      pushd "linux-$KERNEL_VERSION"
         check make ARCH="$KARCH" mproper
         check make ARCH="$KARCH" INSTALL_HDR_PATH="$toolsdir/$target" headers_install
      popd
   
      # Build cross-binutils.
      check tar -xf "$srcdir/$BINUTILS_TAR"
      pushd "binutils-$BINUTILS_VERSION"
         rm -rf build
         mkdir build
         pushd build
            check ../configure            \
               --prefix="$toolsdir"       \
               --host="$host"             \
               --target="$target"         \
               --with-sysroot="$rootdir"  \
               --disable-nls              \
               --disable-multilib         \
               --disable-werror
            check pmake
            check make install
         popd
      popd

      # Build cross-gcc-stage1.
      check tar -xf "$srcdir/$GCC_TAR"
      pushd "gcc-$GCC_VERSION"
         rm -rf build
         mkdir build
         pushd build
            check ../configure            \
               --prefix="$toolsdir"       \
               --host="$host"             \
               --target="$target"         \
               --with-sysroot="$rootdir"  \
               --with-newlib              \
               --without-headers          \
               --enable-languages=c       \
               --enable-initfini-array    \
               --disable-nls              \
               --disable-multiblib        \
               --disable-bootstrap        \
               --disable-shared           \
               --disable-threads          \
               --disable-decimal-float    \
               --disable-libatomic        \
               --disable-libgomp          \
               --disable-libquadmath      \
               --disable-libssp           \
               --disable-libvtv           \
               --disable-libstdcxx

            check pmake
            check make install
         popd
      popd

      # Build cross-libc.
      check tar -xf "$srcdir/$LIBC_TAR"
      pushd "$LIBC-$LIBC_VERSION"
         case "$LIBC" in
         glibc)
            rm -rf build
            mkdir build
            pushd build
               echo "rootsbindir=/usr/sbin" > configparms
            popd
         esac
      popd

      # Build cross-gcc.
   popd
fi

# Install host-kernel-headers.

# Build host-libc.

# Build host-binutils.

# Build host-gcc.

# Build host-make.

# Build host-minipkg2.

# Build host-busybox.

# Build host-kernel.
