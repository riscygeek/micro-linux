
download_busybox() {
   local file url
   file="busybox-$1.tar.bz2"
   url="https://busybox.net/downloads/${file}"
   BUSYBOX_TAR="${TOP}/sources/${file}"

   download "${BUSYBOX_TAR}" "${url}"
}
