#!/usr/bin/env bash

# Default arguments.
KERNEL_VERSION="5.15.11"
BUSYBOX_VERSION="1.35.0"
GCC_VERSION="11.1.0"
BINUTILS_VERSION="2.36.1"
MAKE_VERSION="4.3"
GLIBC_VERSION="2.33"
MUSL_VERSION="1.2.2"
BASH_VERSION="5.1"
IANA_ETC_VERSION="20211224"
MAN_PAGES_VERSION="5.13"

ENABLE_NATIVE_TOOLCHAIN=1
ENABLE_KERNEL=1
ENABLE_BASH=1
ENABLE_MENUCONFIG=1
ENABLE_E2FS=0
ENABLE_IANA_ETC=1
ENABLE_MAN_PAGES=0

TOP="$PWD"
SYSROOT="$PWD/rootfs"
TOOLS="$PWD/tools"
JOBS="$(nproc)"
DO_BUILD=n
export PATH="$TOOLS/bin:$PATH"

BUILD="$(gcc -dumpmachine)"
TARGET="${BUILD}"

for f in lib/*.bash; do
   source "$f"
   #echo "Sourced $f"
done

check_dependencies

# Parse command-line arguments.
parse_cmdline_args "$@"

# Set the libc name.
set_libc "$TARGET"

HOST_ARCH="$(uname -m)"
TARGET_ARCH="$(cut -d'-' -f1 <<< "${TARGET}")"
set_bits "${TARGET_ARCH}"

[[ $DO_BUILD = n ]] && exit 0

log "Build Information:"
indent_log +1
log "Target:   ${TARGET}"
log "Build:    ${BUILD}"
log "Bits:     ${BITS}"
log "Libc:     ${LIBC_NAME}"
indent_log -1

# Download the sources.
download_kernel      "$KERNEL_VERSION"
download_busybox     "$BUSYBOX_VERSION"
download_binutils    "$BINUTILS_VERSION"
download_gcc         "$GCC_VERSION"
download_make        "$MAKE_VERSION"
download_bash        "$BASH_VERSION"
download_iana_etc    "$IANA_ETC_VERSION"
download_man_pages   "$MAN_PAGES_VERSION"
download_libc

[[ $DO_BUILD = d ]] && exit 0

create_rootfs
build_kheaders "${SYSROOT}/usr"


if [[ $TARGET != $BUILD  ]]; then
   if ! has_working_toolchain; then
      # If cross-compiling...
      log "Creating a cross-toolchain..."

      indent_log +1

      # Build the cross-binutils.
      build_cross_binutils

      # Build the stage-1 cross-compiler.
      build_cross_gcc_stage1

      # Build the C standard library.
      build_libc

      # Build the final cross-compiler.
      build_cross_gcc

      # Check the resulting cross-compiler.
      check_cross_gcc

      indent_log -1
   fi

   # Build the C standard library.
   [[ -f $SYSROOT/lib/libc.so ]] || build_libc
else
   # Build the C standard library.
   build_libc

   export CFLAGS="--sysroot=$SYSROOT"
fi

[[ $DO_BUILD = t ]] && exit 0

[[ $TARGET = $BUILD ]] || CROSS="${TARGET}-"

[[ $ENABLE_MAN_PAGES = 1 ]] && build_host_man_pages

if [[ $ENABLE_NATIVE_TOOLCHAIN = 1 ]]; then
   build_host_binutils
   build_host_gcc
   build_host_make
fi

[[ $ENABLE_IANA_ETC  = 1 ]] && build_host_iana_etc
[[ $ENABLE_BASH      = 1 ]] && build_host_bash

build_host_busybox

[[ $ENABLE_KERNEL = 1 ]] && build_kernel

create_files

[[ $ENABLE_E2FS = 1 ]] && create_e2fs
