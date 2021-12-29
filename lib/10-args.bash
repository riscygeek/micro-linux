

print_help() {
   echo "TODO: Help message."
   exit 0
}

parse_cmdline_args() {
   get_arg() {
      eval "$1='$(sed 's/^[^=]\+=//' <<< "$2")'"
   }

   while [[ $@ ]]; do
      case "$1" in
      --help)
         print_help
         ;;
      --clean)
         log "Cleaning old directories..."
         rm -rf "${BUILD}" "${SYSROOT}" "${TOOLS}"
         ;;
      --verbose)
         VERBOSE=1
         ;;
      --target=*)
         get_arg TARGET "$1"
         ;;
      --kernel-version=*)
         get_arg KERNEL_VERSION "$1"
         ;;
      --busybox-version=*)
         get_arg BUSYBOX_VERSION "$1"
         ;;
      --binutils-version=*)
         get_arg BINUTILS_VERSION "$1"
         ;;
      --gcc-version=*)
         get_arg GCC_VERSION "$1"
         ;;
      -*)
         fail "invalid option: $1"
         ;;
      *)
         fail "invalid argument: $1"
         ;;
      esac
      shift
   done
}
