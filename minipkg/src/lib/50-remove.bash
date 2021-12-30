#!/usr/bin/env bash

# Removes a package without checking for the dependencies.
# Args:
#   $1 - package name
purge_package() {
   local f
   is_installed "$1" || fail "Cannot remove non-existent package $1"
   while read -r f; do
      [[ -d $f ]] && continue
      rm -f "$f"
      rmdir -p "$(dirname "$f")" &>/dev/null
   done <"$PKGDIR/$1/files"
   rm -rf "$PKGDIR/$1"
}

# Estimate the size of an installed package.
# Args:
#   $1 - package name
#   $2 * outvar
estimate_local_pkg_size() {
   local res f sz
   res=0
   while read -r f; do
      sz="$(ls -dsk1 "$ROOT/$f" | awk '{print $1}')"
      [[ $sz ]] && res=$((res + sz))
   done <"$PKGDIR/$1/files"
   [[ ${#2} -ne 0 ]] && eval "$2='$res'" || echo "$res"
}

# Interactively remove packages.
# Args:
#   $@ - package names
purge_packages_i() {
   local str pkg pkgver psize size

   log "Estimating size..."
   log

   size=0
   str="Packages (${#@})"
   for pkg in "$@"; do
      pkg_get_local "$pkg" pkgver
      str+=" ${pkg}:${pkgver}"
      estimate_local_pkg_size "$pkg" psize
      size=$((size + psize))
   done
   log "$str"
   log
   log "Total Removed Size: ${size}kiB"
   log

   yesno "Do you want to remove these packages?" y || return 1

   for pkg in "$@"; do
      purge_package "$pkg"
      log "Package $pkg removed."
   done
}

# Interactively remove packages.
# Args:
#   $@ - package names
remove_packages_i() {
   local str pkg pkgver psize size rdeps

   log "Estimating size..."
   log

   size=0
   str="Packages (${#@})"
   for pkg in "$@"; do
      pkg_get_local "$pkg" pkgver
      str+=" ${pkg}:${pkgver}"

      rdeps=()
      list_rdeps "$pkg"
      [[ ${#rdeps[@]} = 0 ]] || fail "One or more packages depend on $1: ${rdeps[@]}"

      estimate_local_pkg_size "$pkg" psize
      size=$((size + psize))
   done
   log "$str"
   log
   log "Total Removed Size: ${size}kiB"
   log

   yesno "Do you want to remove these packages?" y || return 1

   for pkg in "$@"; do
      purge_package "$pkg"
      log "Package $pkg removed."
   done
}