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

   if [[ ! -f $KERNEL_TAR ]]; then
      log "Downloading linux..."
      download "${KERNEL_TAR}" "${url}"
   fi
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
   ARCH="$(kernel_arch "${TARGET}")"
   builddir="build/linux-${KERNEL_VERSION}"

   log "Building the kernel headers..."
   indent_log +1

   # Clean old directories.
   rm -rf "$1/include"

   mkdir -p "$1" build

   # Extract the kernel tarball if not present.
   if [[ ! -d ${builddir} ]]; then
      log "Extracting..."
      check tar -C build -xf "${KERNEL_TAR}"
   fi

   pushd "${builddir}"
      log "Validating..."
      qcheck make ARCH="${ARCH}" mrproper

      log "Installing..."
      qcheck make ARCH="${ARCH}" INSTALL_HDR_PATH="$1" headers_install
   popd

   indent_log -1
}

build_kernel() {
   local ARCH builddir
   ARCH="$(kernel_arch "${TARGET}")"
   builddir="build/linux-${KERNEL_VERSION}"

   kmake() {
      qcheck make ARCH="${ARCH}" CROSS_COMPILE="${CROSS}" "$@"
   }

   log "Building the kernel..."
   indent_log +1

   pushd "${builddir}"

      log "Configuring..."
      if [[ $KERNEL_CONFIG ]]; then
         check cp "$KERNEL_CONFIG" .config
      else
         [[ $KERNEL_DEFCONFIG ]] && kmake "${KERNEL_DEFCONFIG}_defconfig" || kmake defconfig
         [[ $ENABLE_MENUCONFIG = 1 ]] && make ARCH="${ARCH}" CROSS_COMPILE="${CROSS}" menuconfig
      fi

      log "Building..."
      kmake -j"${JOBS}"

      log "Installing..."
      kmake INSTALL_PATH="${SYSROOT}/boot" install
      grep -q CONFIG_MODULES=y .config && kmake INSTALL_MOD_PATH="${SYSROOT}" modules_install
      install -m644 .config "${SYSROOT}/boot/config"

   popd "${builddir}"

   indent_log -1
}


