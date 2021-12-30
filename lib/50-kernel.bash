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
build_host_kheaders() {
   local ARCH builddir
   ARCH="$(kernel_arch "${TARGET}")"
   builddir="build/linux-${KERNEL_VERSION}"

   log "Building the kernel headers..."
   indent_log +1

   mkdir -p build

   # Extract the kernel tarball if not present.
   if [[ ! -d ${builddir} ]]; then
      log "Extracting..."
      check tar -C build -xf "${KERNEL_TAR}"
   fi

   pushd "${builddir}"
      log "Validating..."
      qcheck make ARCH="${ARCH}" mrproper

      log "Installing..."
      qcheck make ARCH="${ARCH}" INSTALL_HDR_PATH="$SYSROOT/usr" headers_install

      if [[ $ENABLE_MINIPKG = 1 ]]; then
         mkdir -p tmp-install/usr
         qcheck make ARCH="${ARCH}" INSTALL_HDR_PATH="tmp-install/usr" headers_install
         minipkg_add "linux-headers" "$KERNEL_VERSION" tmp-install
      fi
   popd

   indent_log -1
}

build_kernel() {
   local ARCH builddir
   ARCH="$(kernel_arch "${TARGET}")"
   builddir="${TOP}/build/linux-${KERNEL_VERSION}"

   kmake() {
      qcheck make ARCH="${ARCH}" CROSS_COMPILE="${CROSS}" "$@"
   }

   log "Building the kernel..."
   indent_log +1

   # Extract the kernel tarball if not present.
   if [[ ! -d ${builddir} ]]; then
      log "Extracting..."
      check tar -C build -xf "${KERNEL_TAR}"
   fi

   pushd "${builddir}"

      log "Configuring..."
      if [[ $KERNEL_CONFIG ]]; then
         check cp "$KERNEL_CONFIG" .config
      else
         [[ $KERNEL_DEFCONFIG ]] && kmake "${KERNEL_DEFCONFIG}_defconfig" || kmake defconfig
      fi
      [[ $ENABLE_MENUCONFIG = 1 ]] && make ARCH="${ARCH}" CROSS_COMPILE="${CROSS}" menuconfig

      # Save the kernel config, if specified.
      if [[ $KERNEL_SAVE_TO = - ]]; then
         cp .config "$KERNEL_CONFIG"
      elif [[ $KERNEL_SAVE_TO ]]; then
         cp .config "$KERNEL_SAVE_TO"
      fi

      log "Building..."
      kmake -j"${JOBS}"

      log "Installing..."
      kmake INSTALL_PATH="${SYSROOT}/boot" install
      grep -q CONFIG_MODULES=y .config && kmake INSTALL_MOD_PATH="${SYSROOT}" modules_install
      install -m644 .config "${SYSROOT}/boot/config"

      if [[ $ENABLE_MINIPKG = 1 ]]; then
         mkdir -p tmp-install/boot
         kmake INSTALL_PATH="$PWD/tmp-install/boot" install
         grep -q CONFIG_MODULES=y .config && kmake INSTALL_MOD_PATH="$PWD/tmp-install" modules_install
         install -m644 .config "tmp-install/boot/config"
         minipkg_add "linux" "$KERNEL_VERSION" tmp-install
      fi

   popd

   indent_log -1
}


