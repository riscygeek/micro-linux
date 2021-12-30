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
   echo "  minipkg info [options] <package>"
   echo "  minipkg download-source <package(s)>"
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
         get_arg ROOT "$1"
         set_root
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
   install|list|remove|purge|clean-cache|info|download-source)
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
   download-source)
      [[ $@ ]] || fail "Usage: minipkg download-source <package(s)>"
      download_source_i "$@"
      ;;
   info)
      [[ $# -lt 1 ]] && fail "Usage: minipkg info <package>"
      parse_package_info "$@"
      ;;
   list)
      parse_list "$@"
      ;;
   clean-cache)
      rm -rf "$BUILDDIR" "$BINPKGSDIR"
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

parse_package_info() {
   local pkg where
   while [[ $@ ]]; do
      case "$1" in
      --local)
         where=local
         ;;
      --repo)
         where=repo
         ;;
      -*)
         fail "Unknown option: $1"
         ;;
      *)
         [[ $pkg ]] && fail "Usage: minipkg info [options] <package>" || pkg="$1"
         ;;
      esac
      shift
   done
   [[ $pkg ]] || fail "Usage: minipkg info [options] <package>"
   package_info "$pkg" "$where"
}
