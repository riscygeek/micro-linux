pushd() { builtin pushd "$1" > /dev/null; }
popd()  { builtin popd       > /dev/null; }

[[ $(id -u) = 0 ]]         \
   || SUDO="$(which sudo)" \
   || fail "Either run this script as root or install sudo."

as_root() {
   "${SUDO}" "$@"
}

LOG_INDENT=1
VERBOSE=0

log() {
   printf "\033[32m*\033[0m%*s" "${LOG_INDENT}" >&2
   echo "$@" >&2
}

indent_log() {
   case "$1" in
   +*|-*)
      LOG_INDENT=$((LOG_INDENT $1))
      ;;
   *)
      LOG_INDENT="$1"
      ;;
   esac
}

fail() {
   echo "$0: $@" >&2
   exit 1
}

check() {
   "$@" || fail "failed to run: $@"
}

qcheck() {
   local log
   if [[ $VERBOSE = 0 ]]; then
      log="$("$@" 2>&1)" || { echo "${log}"; fail "failed to run: $@"; }
   else
      check "$@"
   fi
}

# Download a file.
# Args:
#   $1 - Destination path
#   $2 - URL
download() {
   if [[ ! -f $1 ]]; then
      mkdir -p "$(dirname "$1")"
      wget -O "$1" "$2" || { rm -f "$1"; fail "Failed to download '$2'"; }
   fi
}

# Print out the bitwidth of the arch.
bits() {
   case "$1" in
   i[3456]86)
      BITS=32
      ;;
   x86_64)
      BITS=64
      ;;
   arm|armv*)
      BITS=32
      ;;
   aarch64)
      BITS=64
      ;;
   riscv32)
      BITS=32
      ;;
   riscv64)
      BITS=64
      ;;
   *)
      fail "Failed to get bitwidth of architecture '$1'. See bits() in lib/00-util.bash."
   esac
}
