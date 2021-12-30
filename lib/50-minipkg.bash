#!/usr/bin/env bash

# Add a package to minipkg.
# Args:
#   - $1       - package name
#   - $2       - package version
#   - (stdin)  - list of files
minipkg_add() {
   local dir
   [[ $ENABLE_MINIPKG = 1 ]] || return

   dir="$SYSROOT/var/db/minipkg/packages/$1"
   mkdir -p "$dir"

   pushd "$3"
      find | sed 's@./@/@' > "$dir/files"
   popd
}

build_host_minipkg() {
   log "Installing minipkg..."
   pushd "minipkg"
      qcheck ./install.sh "$SYSROOT"

      mkdir -p tmp-install
      qcheck ./install.sh --no-repo "$PWD/tmp-install"
      minipkg_add "minipkg" "$MINIPKG_VERSION" tmp-install
      rm -rf tmp-install
   popd
}

minipkg_download_sources() {
   [[ ${#DOWNLOAD_SOURCES[@]} = 0 ]] && return
   log "Downloading package sources..."
   qcheck "$TOP/minipkg/src/minipkg" --root="$SYSROOT" download-source ${DOWNLOAD_SOURCES[@]}
}
