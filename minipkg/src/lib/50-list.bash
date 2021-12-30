#!/usr/bin/env bash

list_installed() {
   local dir pkgname pkgver description
   pushd "$PKGDIR"
      for name in *; do
         dir="$PKGDIR/$name"
         [[ -f $dir/package.info ]] || continue
         pkg_get_from "$dir/package.info" pkgname
         pkg_get_from "$dir/package.info" pkgver
         [[ -L $dir ]] && echo "$name $pkgver (provided by $pkgname)" || echo "$pkgname $pkgver"
      done
   popd
}

list_available() {
   local pkgfile pkgname pkgver installed tmp
   pushd "$REPODIR"
      for pkg in *; do
         pkgfile="$REPODIR/$pkg"
         pkg_get_from "$pkgfile" pkgname
         pkg_get_from "$pkgfile" pkgver
         if is_installed "$pkgname"; then
            tmp="$pkgver"
            pkg_get_local "$pkgname" pkgver
            echo "$pkgname $tmp [installed: $pkgver]"
         else
            echo "$pkgname $pkgver"
         fi
      done
   popd
}

# List all files this package installs.
# Args:
#   $1 - package name
list_files() {
   is_installed "$1" || fail "Local package $1 not found."
   cat "$PKGDIR/$1/files"
}

# List all runtime dependencies a package has.
# Args:
#   $1      - package name
#   $2      - local or repo
#   depends * Output variable
list_depends() {
   if [[ $2 = repo ]]; then
      pkg_get "$1" depends
   elif [[ $2 = local ]]; then
      is_installed "$1" || fail "Package $1 is not installed."
      pkg_get_from "$PKGDIR/$1/package.info" depends
   else
      fail "list_depends(): \$2 must be either local or repo"
   fi
}

# Check if a package has a specific dependency.
# Args:
#   $1 - package name
#   $2 - dependency package
#   $3 - local or repo
has_dependency() {
   local depends pkg
   list_depends "$1" "$3"
   for pkg in "${depends[@]}"; do
      [[ $pkg = $2 ]] && return 0
   done
   return 1
}

# List all reverse-dependencies of a package.
# Args:
#   $1      - package name
#   rdeps   * Output variable
list_rdeps() {
   local pkg depends
   pushd "$PKGDIR"
      for pkg in *; do
         has_dependency "$pkg" "$1" 'local' && rdeps+=("$pkg")
      done
   popd
}
