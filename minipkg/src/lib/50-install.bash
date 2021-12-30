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

# Check if this package is provided by another package.
is_foreign() {
   [[ -L $PKGDIR/$1 ]]
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

   mkdir -p "$BINPKGSDIR"
   check install -Dm644 "$pb_binpkg" "$BINPKGSDIR/"

   [[ ${#2} -ne 0 ]] && eval "${2}='${pb_binpkg}'"
}

# Args:
#   $1 - package name
#   $2 * outfile
check_conflicts() {
   local conflicts provides pkg ec pkgname
   ec=0

   pkg_get "$1" conflicts
   pkg_get "$1" provides

   for pkg in "${conflicts[@]}"; do
      is_installed "$pkg" && eval "$2+=('$pkg')" && ec=1
   done

   #for pkg in "${provides[@]}"; do
   #   if is_installed "$1"; then
   #      pkg_get_local "$pkg" pkgname
   #      [[ $pkgname = $1 ]] && continue
   #      fail "$pkg is already provided by $pkg"
   #   fi
   #done

   return "$ec"
}

# Install a binary package.
# Args:
#   $1 - bmpkg file
#   $2 - root
install_package() {
   local pkgname pkgver pkgdir provides pkg

   pkgname="$(tar -xf "$1" .meta/name -O)" || fail "Invalid package format"
   pkgver="$(tar -xf "$1" .meta/version -O)" || fail "Invalid package format"

   if is_installed "${pkgname}"; then
      #warn "Package ${pkgname} is already installed as version ${pkgver}!"
      purge_package "${pkgname}"
      true
   fi

   log "Installing ${pkgname}:${pkgver}..."
   pkgdir="$PKGDIR/${pkgname}"
   check mkdir -p "$pkgdir"
   check mkdir -p "$ROOT"
   check tar -tf "$1" --exclude='.meta' | awk '{printf "/%s\n", $0}' > "$pkgdir/files"
   check tar -C "$2" -xf "$1" --exclude='.meta*'
   check tar -xf "$1" .meta/package.info -O > "$pkgdir/package.info"

   pkg_get_from "$pkgdir/package.info" provides
   for pkg in "${provides[@]}"; do
      check ln -s "$pkgname" "$PKGDIR/$pkg"
   done
}

# Find a binary package if available.
# Args:
#   $1 - package name
#   $2 * binpkg
find_binpkg() {
   local tmp
   [[ -d $BINPKGSDIR ]] || return 1
   tmp="$(ls "$BINPKGSDIR" | grep "^$1:[^:]\+\.bmpkg\.tar\.gz\$" | sort -nr | head -n1)"
   [[ $tmp ]] || return 1
   tmp="$BINPKGSDIR/$tmp"
   [[ ${#2} -ne 0 ]] && eval "$2='$tmp'" || echo "$tmp"
   return 0
}


# Interactively install packages.
# Args:
#   $1 - `--just-download` (optional)
#   $@ - packages
install_packages_i() {
   local -a pkgs binpkgs will_be_installed
   local pkg binpkg str pkgver pkg_conflicts other remove provides subpkg

   [[ -z $depth ]] && depth=2

   add_package() {
      local pkg force
      [[ $1 = -f ]] && force=1 && shift
      
      [[ $force != 1 && $depth -ge 2 ]] && is_installed "$1" && return 0
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

   if [[ $depth -ge 2 ]]; then
      for pkg in "$@"; do
         if is_installed "$pkg"; then
            if is_foreign "$pkg"; then
               pkg_get_local "$pkg" pkgname
               warn "Package $pkg is already provided by $pkgname. $pkgname will be uninstalled."
               remove+=("$pkgname")
            else
               warn "Package $pkg is already installed."
            fi
         fi
         pkg_get "${pkg}" provides
         for subpkg in "${provides[@]}"; do
            if is_installed "$subpkg"; then
               pkg_get_local "$subpkg" pkgname
               [[ $pkgname = $pkg ]] && continue
               warn "Package $subpkg is already provided by $pkgname. $pkgname will be uninstalled."
               remove+=("$subpkg")
            fi
         done
      done
   fi

   log "Resolving dependencies..."
   log

   for pkg in "$@"; do
      find_dependencies "${pkg}"
      add_package -f "${pkg}"
   done

   # Check for package conflicts.
   if [[ $depth -ge 2 ]]; then
      for pkg in "${pkgs[@]}"; do
         if ! check_conflicts "$pkg" pkg_conflicts; then
            for other in "${pkg_conflicts[@]}"; do
               if contains "$other" "${pkgs[@]}"; then
                  fail "$pkg conflicts with $other"
               else
                  warn "$pkg conflicts with $other. $other will be uninstalled."
                  remove+=("$other")
               fi
            done
         fi
      done
      [[ ${#remove[@]} -ne 0 ]] && log
   fi

   str="Packages (${#pkgs[@]})"
   for pkg in "${pkgs[@]}"; do
      pkg_get "$pkg" pkgver
      str+=" ${pkg}:${pkgver}"
   done

   log "$str"
   [[ $depth -ge 2 ]] && { log; yesno "Proceed with installation?" y || return 1; }

   log
   log "Downloading packages..."
   for i in "${!pkgs[@]}"; do
      pkg="${pkgs[$i]}"
      if [[ $depth -ge 2 ]] && find_binpkg "$pkg" binpkg; then
         yesno "Found prebuilt binary package for ${pkg}:${pkgver}. Use it?" y \
            && unset pkgs["$i"]     \
            && binpkgs+=("$binpkg") \
            && continue
      fi
      pkg_get "$pkg" pkgver
      log "($((i+1))/${#pkgs[@]}) Downloading ${pkg}:${pkgver}..."
      download_sources "${pkg}"
   done


   if [[ $depth -ge 1 ]]; then
      if [[ ${#pkgs[@]} -ne 0 ]]; then
         log
         log "Building packages..."
         for i in "${!pkgs[@]}"; do
            pkg="${pkgs[$i]}"
            pkg_get "$pkg" pkgver
            log "($((i+1))/${#pkgs[@]}) Building $pkg:${pkgver}..."
            build_package "${pkg}" binpkg
            binpkgs+=("$binpkg")

            [[ $depth -lt 2 ]] && cp "$binpkg" "$PWD/"
         done
      fi

      if [[ $depth -ge 2 ]]; then
         if [[ ${#remove[@]} -ne 0 ]]; then
            log
            log "Removing conflicting packages..."
            for pkg in "${remove[@]}"; do
               will_be_installed=("${pkgs[@]}" "${remove[@]}")
               remove_packages_i "$pkg"
            done
         fi
         log
         log "Installing packages..."
         for i in "${!binpkgs[@]}"; do
            binpkg="${binpkgs[$i]}"
            log "($((i+1))/${#binpkgs[@]}) Installing ${binpkg}..."
            install_package "$binpkg" "$ROOT"
         done
      fi
   fi
}

download_source_i() {
   depth=0 install_packages_i "$@"
}
