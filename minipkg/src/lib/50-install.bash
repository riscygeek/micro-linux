#!/usr/bin/env bash

# Find a package file.
# Args:
#   $1 - package name
#   $2 * outvar
find_package() {
   local file
   file="$REPODIR/$1.mpkg"
   [[ -f $file ]] || fail "Package not found: '$1'"
   [[ ${#2} -ne 0 ]] && eval "$2='${file}'" || echo "${file}"
}


# Check if a package is already installed.
is_installed() {
   [[ -d $PKGDIR/$1 ]]
}

# Load a package parameter from a file.
# Args:
#   $1 - pkgfile
#   $2 - parameter name
pkg_get_from() {
   eval "$(grep -m1 "^$2=.*" "$1")"
}

# Load a package parameter (eg. version).
# Args:
#   $1 - package name
#   $2 - parameter name
pkg_get() {
   local pg_file
   find_package "$1" pg_file
   pkg_get_from "$pg_file" "$2"
}

# Load a package parameter from the local package.
# Args:
#   $1 - package name
#   $2 - parameter name
pkg_get_local() {
   local pg_file
   is_installed "$1" || fail "Package $1 is not installed"
   pkg_get_from "$PKGDIR/$1/package.info" "$2"
}

# Build a binary package.
# Args:
#   $1 - package name
#   $2 * resulting binary package
build_package() {
   local basedir srcdir builddir pkgdir
   local pkgver pkgfile pb_binpkg

   find_package "$1" pkgfile
   pkg_get "$1" pkgver

   basedir="$(realpath "${BUILDDIR}/$1-${pkgver}")"
   srcdir="${basedir}/src"
   builddir="${basedir}/build"
   pkgdir="${basedir}/pkg"

   mkdir -p "${builddir}"
   rm -rf "${pkgdir}"

   # This must be run in a sub-shell
   # to avoid overwriting shell variables.
   (                          \
      source "${pkgfile}";    \
      cd "${builddir}";       \
      S="${srcdir}";          \
      B="${builddir}";        \
      echo "prepare()";       \
      prepare || exit 1;      \
      echo "build()";         \
      build || exit 1;        \
      D="${pkgdir}";          \
      mkdir -pv "${pkgdir}";  \
      echo "package()";       \
      package || exit 1       \
   ) &> "${basedir}/log"|| fail "Failed to build $1. Log file: ${basedir}/log"

   pb_binpkg="${basedir}/$1:${pkgver}.bmpkg.tar.gz"

   # Create a binary package.
   pushd "${pkgdir}"
      mkdir .meta
      echo "$1"         > .meta/name
      echo "${pkgver}"  > .meta/version
      check cp "${pkgfile}" .meta/package.info
      tar -czf "${pb_binpkg}" $(ls) .meta
   popd

   [[ ${#2} -ne 0 ]] && eval "${2}='${pb_binpkg}'"
}

# Install a binary package.
# Args:
#   $1 - bmpkg file
#   $2 - root
install_package() {
   local pkgname pkgver pkgdir

   pkgname="$(tar -xf "$1" .meta/name -O)" || fail "Invalid package format"
   pkgver="$(tar -xf "$1" .meta/version -O)" || fail "Invalid package format"

   if is_installed "${pkgname}"; then
      warn "Package ${pkgname} is already installed as version ${pkgver}!"
      # TODO: remove old
      true
   fi

   log "Installing ${pkgname}:${pkgver}..."
   pkgdir="$PKGDIR/${pkgname}"
   check mkdir -p "$pkgdir"
   check mkdir -p "$ROOT"
   check tar -tf "$1" --exclude='.meta' | awk '{printf "/%s\n", $0}' > "$pkgdir/files"
   check tar -C "$2" -xf "$1" --exclude='.meta*'
   check tar -xf "$1" .meta/package.info -O > "$pkgdir/package.info"
}


# Interactively install packages.
# Args:
#   $@ - packages
install_packages_i() {
   local -a pkgs binpkgs pkgvers
   local pkg binpkg str pkgver

   add_package() {
      local pkg force
      [[ $1 = -f ]] && force=1 && shift
      
      [[ $force != 1 ]] && is_installed "$1" && return 0
      for pkg in "${pkgs[@]}"; do
         [[ ${pkg} = $1 ]] && return 0
      done
      pkgs+=("$1")
   }

   find_dependencies() {
      local dep depends bdepends
      pkg_get "$1" depends
      pkg_get "$1" bdepends
      for dep in "${depends[@]}" "${bdepends[@]}"; do
         find_dependencies "${dep}"
         add_package "${dep}"
      done
   }

   download_sources() {
      local src pkgver sources srcdir
 
      pkg_get "$1" pkgver
      pkg_get "$1" sources

      srcdir="${BUILDDIR}/$1-${pkgver}/src"

      mkdir -p "${srcdir}"
      pushd "${srcdir}"
         for src in "${sources[@]}"; do
            download "${src}"
         done
      popd
   }

   log "Resolving dependencies..."
   log

   for pkg in "$@"; do
      pkg_get "$pkg" pkgver
      pkgvers["$pkg"]="$pkgver"
      find_dependencies "${pkg}"
      add_package -f "${pkg}"
   done

   str="Packages (${#pkgs[@]})"
   for pkg in "${pkgs[@]}"; do
      str+=" ${pkg}:${pkgvers[$pkg]}"
   done
   log "$str"
   log
   yesno "Proceed with installation?" y || return 1

   log
   log "Downloading packages..."
   for (( i=0; i < ${#pkgs[@]}; i++ )); do
      pkg="${pkgs[$i]}"
      log "($((i+1))/${#pkgs[@]}) Downloading $pkg:${pkgvers[$pkg]}..."
      download_sources "${pkg}"
   done

   log
   log "Building packages..."
   for (( i=0; i < ${#pkgs[@]}; i++ )); do
      pkg="${pkgs[$i]}"
      log "($((i+1))/${#pkgs[@]}) Building $pkg:${pkgvers[$pkg]}..."
      build_package "${pkg}" binpkg
      binpkgs+=("$binpkg")
   done

   log
   log "Installing packages..."
   for binpkg in "${binpkgs[@]}"; do
      install_package "$binpkg" "$ROOT"
   done
}
