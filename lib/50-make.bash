#!/usr/bin/env bash

# Download the make and set the MAKE_TAR variable.
# Args:
#   $1 - version
download_make() {
   local file url
   file="make-$1.tar.gz"
   url="https://ftp.gnu.org/gnu/make/${file}"
   MAKE_TAR="${TOP}/sources/${file}"

   download "${MAKE_TAR}" "${url}"
}
