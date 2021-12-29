
print_help() {
   echo "TODO: Help message."
   exit 0
}

parse_cmdline_args() {
   while [[ $@ ]]; do
      case "$arg" in
      --help)
         print_help
         ;;

      esac
   done
}
