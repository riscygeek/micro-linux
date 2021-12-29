pushd() { builtin pushd "$1" > /dev/null; }
popd()  { builtin popd       > /dev/null; }
pmake() { make -j"${JOBS}";               }

if [[ $(id -u) = 0 ]]; then
   sudo() { "$@"; }
elif ! which sudo >/dev/null; then
   fail "Either run this script as root or install sudo."
fi

# LOGGING

LOG_INDENT=1
VERBOSE=0

# Args:
#   $1      - star color
#   $2-$... - text to print
print() {
   printf '\033[%sm*\033[0m%*s' "$1" "${LOG_INDENT}" >&2
   shift
   echo "$@" >&2
}

log() {
   print 32 "$@"
}
warn() {
   print 33 "$@"
}
fail() {
   print 31 "$@"
   exit 1
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


check() {
   "$@" || fail "failed to run: $@"
}

qcheck() {
   local log
   if [[ $VERBOSE = 0 ]]; then
      log="$("$@" 2>&1)" || { tee "${TOP}/error.log" <<< "${log}"; fail "failed to run: $@"; }
   else
      check "$@"
   fi
}

# Download a file.
# Args:
#   $1 - Destination path
#   $2 - URL
download() {
   local flags
   if [[ ! -f $1 ]]; then
      mkdir -p "$(dirname "$1")"
      [[ $VERBOSE = 1 ]] || flags="-q"
      wget "$flags" -O "$1" "$2" || { rm -f "$1"; fail "Failed to download '$2'"; }
   fi
}

# Print out the bitwidth of the arch.
set_bits() {
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
