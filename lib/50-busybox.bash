#!/usr/bin/env bash

download_busybox() {
   local file url
   file="busybox-$1.tar.bz2"
   url="https://busybox.net/downloads/${file}"
   BUSYBOX_TAR="${TOP}/sources/${file}"

   if [[ ! -f $BUSYBOX_TAR ]]; then
      log "Downloading busybox..."
      download "${BUSYBOX_TAR}" "${url}"
   fi
}


build_host_busybox() {
   local ARCH builddir
   ARCH="$(kernel_arch "${TARGET}")"
   builddir="build/busybox-${BUSYBOX_VERSION}"

   log "Building busybox..."
   indent_log +1

   if [[ ! -d ${builddir} ]]; then
      log "Extracting..."
      check tar -C build -xf "$BUSYBOX_TAR"
   fi

   bbmake() {
      qcheck make ARCH="${ARCH}" CROSS_COMPILE="${CROSS}" "$@"
   }

   pushd "${builddir}"
      log "Cleaning up..."
      qcheck make distclean

      log "Configuring..."
      if [[ $BUSYBOX_CONFIG ]]; then
         check cp "$BUSYBOX_CONFIG" .config
      else
         qcheck make ARCH="${ARCH}" defconfig
         [[ $ENABLE_MENUCONFIG = 1 ]] && make ARCH="${ARCH}" menuconfig
      fi

      if [[ ${LIBC_NAME} = musl ]]; then
         # See: http://clfs.org/view/clfs-embedded/x86/final-system/busybox.html
         sed -i 's/\(CONFIG_\)\(.*\)\(INETD\)\(.*\)=y/# \1\2\3\4 is not set/g' .config
         sed -i 's/\(CONFIG_IFPLUGD\)=y/# \1 is not set/' .config
         sed -i 's/\(CONFIG_FEATURE_WTMP\)=y/# \1 is not set/' .config
         sed -i 's/\(CONFIG_FEATURE_UTMP\)=y/# \1 is not set/' .config
         sed -i 's/\(CONFIG_UDPSVD\)=y/# \1 is not set/' .config
         sed -i 's/\(CONFIG_TCPSVD\)=y/# \1 is not set/' .config
      fi

      log "Building..."
      bbmake -j"${JOBS}"

      log "Installing..."
      bbmake CONFIG_PREFIX="${SYSROOT}" install
      install -Dm755 examples/depmod.pl "${TOOLS}/bin/depmod.pl"
   popd

   indent_log -1
}
