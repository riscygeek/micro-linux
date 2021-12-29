fail() {
   echo "$0: $@" >&2
   exit 1
}

check() {
   "$@" || fail "failed to run: $@"
}

# Download a file.
# Args:
#   $1 - Destination path
#   $2 - URL
download() {
   [[ -f $1 ]] || { mkdir -p "$(dirname "$1")"; check wget -O "$1" "$2"; }
}
