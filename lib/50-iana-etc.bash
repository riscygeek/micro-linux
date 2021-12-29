#!/usr/bin/env bash

# Download iana-etc and set the IANA_ETC_TAR variable.
# Args:
#   $1 - version
download_iana_etc() {
   local file url
   if [[ `cut -d'.' -f1 <<< "$IANA_ETC_VERSION"` -le 2 ]]; then
      file="iana-etc-$1.tar.bz2"
      url="http://sethwklein.net/${file}"
   else
      file="iana-etc-$1.tar.gz"
      url="https://github.com/Mic92/iana-etc/releases/download/${IANA_ETC_VERSION}/${file}"
   fi
   IANA_ETC_TAR="${TOP}/sources/${file}"

   if [[ ! -f $IANA_ETC_TAR ]]; then
      log "Downloading iana-etc..."
      download "${IANA_ETC_TAR}" "${url}"
   fi
}

build_host_iana_etc() {
   local builddir
   builddir="build/iana-etc-${IANA_ETC_VERSION}"

   log "Building iana-etc..."
   indent_log +1

   if [[ ! -d ${builddir} ]]; then
      log "Extracting..."
      check tar -C build -xf "$IANA_ETC_TAR"
   fi

   pushd "${builddir}"
      log "Installing..."
      cp services protocols "$SYSROOT/etc"
   popd
   indent_log -1
}
