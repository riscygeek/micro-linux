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
      url+="/v$(cut -d. -f1 <<< "$1").x/${file}"
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
   builddir="build/linux-${KERNEL_VERSION}"

   log "Building the kernel headers..."
   indent_log +1

   # Clean old directories.
   rm -rf "$1/include"
   rm -rf "${builddir}"

   mkdir -p "$1" build

   # Extract the kernel tarball if not present.
   log "Extracting the kernel tarball..."
   check tar -C build -xf "${KERNEL_TAR}"

   pushd "${builddir}"
      # Install the kernel headers.
      log "Validating the kernel..."
      qcheck make ARCH="${ARCH}" mrproper

      log "Creating the kernel headers..."
      qcheck make ARCH="${ARCH}" headers
      find usr/include -name '.*' -delete
      rm -f usr/include/Makefile

      log "Installing the kernel headers..."
      qcheck cp -rv usr/include "$1/include"
   popd

   indent_log -1
}


