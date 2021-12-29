#!/usr/bin/env bash

# Download the kernel and set the KERNEL_TAR variable.
# Args:
#   $1 - version
download_kernel() {
   local file url
   url="https://mirrors.edge.kernel.org/pub/linux/kernel"

   case "$1" in
   1.*|2.*)
      file="linux-$1.tar.gz"
      url+="/v$(awk -F. '{printf "%s.%s", $1, $2}' <<< "$1")/${file}"
      ;;
   *)
      file="linux-$1.tar.xz"
      url+="v$(cut -d. -f1 <<< "$1")/${file}"
      ;;
   esac

   KERNEL_TAR="${TOP}/sources/${file}"

   download "${KERNEL_TAR}" "${url}"
}

# Print the ARCH variable for kernel builds.
# Args:
#   $1 - target
kernel_arch() {
   case "$(cut -d'-' -f1 <<< "$1")" in
   i[3456]86|x86_64)
      echo x86
      ;;
   riscv*)
      echo riscv
      ;;
   arm|armv*|aarch64)
      echo arm
      ;;
   *)
      fail 'failed to determine kernel architecture. Look into kernel_arch().'
      ;;
   esac
}

# Install the kernel headers.
# Args:
#   $1 - DESTDIR
#   $2 - host arch
build_kheaders() {
   local ARCH builddir
   ARCH="$(kernel_arch "$2")"
   builddir="build/kheaders-${ARCH}"

   # Extract the kernel tarball if not present.
   [[ -d ${builddir} ]] || { mkdir -p build; tar -C "${builddir}" -xf "${TOP}/sources/${KERNEL_TAR}"; }

   pushd "${builddir}"
      # Install the kernel headers.
      make ARCH="${ARCH}" headers_check || exit 1
      make ARCH="${ARCH}" INSTALL_HDR_PATH="$1/$2/include" headers_install || exit 1
   popd
}


