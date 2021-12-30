#!/usr/bin/env bash

# Print information about a package.
# Args:
#   $1 - package name
#   $2 - local or repo
package_info() {
   local pkgfile pkgname pkgver description url bdepends depends
   if [[ $2 = local ]]; then
      is_installed "$1" || fail "No such package: $1"
      pkgfile="$PKGDIR/$1/package.info"
   elif [[ $2 = repo ]]; then
      find_package "$1" pkgfile
   else
      is_installed "$1" && pkgfile="$PKGDIR/$1/package.info" || find_package "$1" pkgfile
   fi

   print_line() {
      local first
      first="$1"
      shift
      printf "%s%*s: %s\n" "$first" $((30 - ${#first})) "" "$@"
   }

   pkg_get_from "$pkgfile" pkgname
   pkg_get_from "$pkgfile" pkgver
   pkg_get_from "$pkgfile" description
   pkg_get_from "$pkgfile" url
   pkg_get_from "$pkgfile" bdepends
   pkg_get_from "$pkgfile" depends

   [[ -z $bdepends ]] && bdepends="None"
   [[ -z $depends ]]  &&  depends="None"

   print_line "Name"                   "$pkgname"
   print_line "Version"                "$pkgver"
   print_line "Description"            "$description"
   print_line "URL"                    "$url"
   print_line "Build Dependencies"     "${bdepends[@]}"
   print_line "Runtime Dependencies"   "${depends[@]}"
}
