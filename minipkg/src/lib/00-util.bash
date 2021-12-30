#!/usr/bin/env bash

pushd() { builtin pushd "$1" > /dev/null; }
popd()  { builtin popd       > /dev/null; }

# LOGGING

LOG_INDENT=1
VERBOSE=0

# Args:
#   $1      - "-n", gets passed to echo
#   $1      - star color
#   $2-$... - text to print
print() {
   local arg
   [[ $1 = -n ]] && arg="-n" && shift
   printf '\033[%sm*\033[0m%*s' "$1" "${LOG_INDENT}" >&2
   shift
   echo $arg "$@" >&2
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

# Print a prompt.
# Args:
#   $1 - question
#   $2 - default answer
prompt() {
   local resp
   print -n 34 "$1"
   read resp
   [[ $resp ]] && echo "$resp" || echo "$2"
}

# Print a yes/no prompt.
# Args:
#   $1 - question
#   $2 - default answer (y or n)
yesno() {
   local str
   [[ "$2" = y ]] && str="$1 [Y/n] " || str="$1 [y/N] "
   [[ `prompt "$str" "$2"` =~ ^[yY] ]]
}

# Download a file.
# Args:
#   $1 - URL
#   $2 - Destination path (optional)
download() {
   local dest flags
   [[ $VERBOSE = 1 ]] || flag="-q"

   if [[ $# -eq 1 ]]; then
      dest="$(grep -o "/[^/]\+$" <<< "$1" | cut -b2-)"
   elif [[ $# -eq 2 ]]; then
      dest="$2"
   fi

   if [[ ! -f $dest ]]; then
      mkdir -p "$(dirname "$dest")"
      [[ $VERBOSE = 1 ]] || flags="-q"
      wget "$flags" -O "$dest" "$1" || { rm -f "$dest"; fail "Failed to download '$1'"; }
   fi
}

# Args:
# $1  - value
# $@  - list
contains() {
   local value e
   value="$1"
   shift
   for e in "$@"; do
      [[ $e = $value ]] && return 0
   done
   return 1
}
