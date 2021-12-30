#!/bin/sh

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
   echo "Usage: ./install.sh [DESTDIR]"
   exit 0
fi

if [ "$1" ]; then
   echo "$1" | grep '^/.*$' || { echo "install.sh: DESTDIR must be an absolute path"; exit 1; }
   DESTDIR="$1"
else
   DESTDIR="/"
fi

install -Dvm755 src/minipkg "${DESTDIR}/usr/bin/minipkg"             || exit 1
install -Dvm644 minipkg.8 "${DESTDIR}/usr/share/man/man8/minipkg.8"  || exit 1

cp -rv repo "${DESTDIR}/var/db/minipkg/" || exit 1

# Fix paths in the script.
sed \
   -e 's#^ROOT=.*$#ROOT=/#'                           \
   -e 's#^LIBDIR=.*$#LIBDIR=/usr/libexec/minipkg#'    \
   -e 's#^REPODIR=.*$#REPODIR=/var/db/minipkg/repo#'  \
   -i "${DESTDIR}/usr/bin/minipkg"

cd src/lib
for f in $(find -type f); do
   install -Dvm644 "$f" "${DESTDIR}/usr/libexec/minipkg/$f" || exit 1
done

echo "Successfully installed!"
