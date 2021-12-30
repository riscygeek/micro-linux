#!/usr/bin/env bash

print_help() {
   echo "Micro-Linux Package Manager $VERSION"
   echo
   echo "Usage: minipkg <operation> [...]"
   echo
   echo "Operations:"
   echo "  minipkg help"
   echo "  minipkg install <package(s)>"
   echo "  minipkg remove <package(s)>"
   echo "  minipkg purge <package(s)>"
   echo "  minipkg list [options]"
   echo "  minipkg clean-cache"
   echo
   echo "Written by Benjamin Stürz <benni@stuerz.xyz>"
}

print_usage() {
   echo "Usage: minipkg --help" >&2
}
get_arg() {
   eval "$1='$(sed 's/^[^=]\+=//' <<< "$2")'"
}

parse_cmdline_args() {
   [[ $1 ]] || { print_usage; exit 1; }


   # Parse common options.
   while [[ $@ ]]; do
      case "$1" in
      -h|--help)
         print_help
         exit 0
         ;;
      --version)
         echo "$VERSION"
         exit 0
         ;;
      --root=*)
         get_arg "$1" ROOT
         shift
         ;;
      -*)
         fail "Unknown option: '$1'"
         ;;
      *)
         break
         ;;
      esac
   done

   # Parse the operation.
   case "$1" in
   help)
      print_help
      exit 0
      ;;
   install|list|remove|purge)
      OPERATION="$1"
      shift
      ;;
   -*)
      print_usage
      exit 1
      ;;
   *)
      fail "Usage: minipkg help"
      ;;
   esac

   case "${OPERATION}" in
   install)
      [[ $@ ]] || fail "Usage: minipkg install <package(s)>"
      install_packages_i "$@"
      ;;
   remove)
      [[ $@ ]] || fail "Usage: minipkg remove <package(s)>"
      remove_packages_i "$@"
      ;;
   purge)
      [[ $@ ]] || fail "Usage: minipkg purge <package(s)>"
      purge_packages_i "$@"
      ;;
   list)
      parse_list "$@"
      ;;
   clean-cache)
      rm -rf "$BUILDDIR"
      ;;
   *)
      fail "Unimplemented operation '${OPERATION}'"
      ;;
   esac
}

parse_list() {
   local pkg
   if [[ $# -eq 0 ]]; then
      list_installed
   else
      case "$1" in
      --installed)
         list_installed
         ;;
      --installable|--available)
         list_available
         ;;
      --files=*)
         get_arg pkg "$1"
         list_files "$pkg"
         ;;
      -*)
         fail "Usage: minipkg list [option]"
         ;;
      esac
   fi
}
