#!/usr/bin/env bash

print_help() {
   echo "Micro-Linux Package Manager $VERSION"
   echo
   echo "Usage: minipkg <operation> [...]"
   echo
   echo "Operations:"
   echo "  minipkg help"
   echo "  minipkg install <package(s)>"
   echo "  minipkg list [options]"
   echo
   echo "Written by Benjamin Stürz <benni@stuerz.xyz>"
}

print_usage() {
   echo "Usage: minipkg --help" >&2
}

parse_cmdline_args() {
   [[ $1 ]] || { print_usage; exit 1; }

   get_arg() {
      eval "$1='$(sed 's/^[^=]\+=//' <<< "$2")'"
   }

   # Parse the operation.
   case "$1" in
   -h|--help|help)
      print_help
      exit 0
      ;;
   --version)
      echo "$VERSION"
      exit 0
      ;;
   install|list)
      OPERATION="$1"
      shift
      ;;
   -*)
      print_usage
      exit 1
      ;;
   esac

   while [[ $@ ]]; do
      case "$1" in
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

   case "${OPERATION}" in
   install)
      [[ $@ ]] || fail "Usage: minipkg install <package(s)>"
      install_packages "$@"
      ;;
   *)
      fail "Unimplemented operation '${OPERATION}'"
      ;;
   esac
}
