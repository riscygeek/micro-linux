#!/usr/bin/env bash

create_rootfs() {
   log "Creating a template rootfs..."

   # Create base directories.
   mkdir -p "${SYSROOT}"/{boot,dev,etc,home,mnt,opt,proc,root,run,srv,sys,tmp}
   mkdir -p "${SYSROOT}"/usr/{bin,include,lib,libexec,share,src}
   mkdir -p "${SYSROOT}"/var/{lock,log,run,spool,tmp}
   mkdir -p "${SYSROOT}"/etc/network/if-{post-{up,down},pre-{up,down},up,down}.d

   # Create symlinks.
   symlink() {
      [[ -L "$2" ]] || check ln -sf "$1" "$2"
   }

   symlink . "${SYSROOT}/usr/local"
   symlink ../etc "${SYSROOT}/usr/etc"
   symlink lib "${SYSROOT}/usr/lib${BITS}"
   symlink bin "${SYSROOT}/usr/sbin"
   symlink usr/bin "${SYSROOT}/bin"
   symlink usr/sbin "${SYSROOT}/sbin"
   symlink usr/lib "${SYSROOT}/lib"
   symlink usr/lib "${SYSROOT}/lib${BITS}"
   symlink ../proc/mounts "${SYSROOT}/etc/mtab"

   check touch "${SYSROOT}/var/log/lastlog"

   # Change permissions.
   check chmod 700 "${SYSROOT}/root"
   check chmod 777 "${SYSROOT}/tmp"
   check chmod 777 "${SYSROOT}/var/tmp"
   check chmod 664 "${SYSROOT}/var/log/lastlog"

   # Create device files.
   # Args:
   #   $1 - path
   #   $2 - mode
   #   $3 - major
   #   $4 - minor
   mkchardev() {
      [[ -c $1 ]] || check sudo mknod -m "$2" "$1" c "$3" "$4"
   }
   mkchardev "${SYSROOT}/dev/console"  600 5 1
   mkchardev "${SYSROOT}/dev/null"     666 1 3
   mkchardev "${SYSROOT}/dev/zero"     666 1 5
   mkchardev "${SYSROOT}/dev/full"     666 1 7
}

create_files() {
   local f pkg
   log "Creating system-configuration files..."

   for f in files/{etc,root,usr}; do
      cp -r "$f" "$SYSROOT"
   done

   if [[ $ENABLE_MINIPKG = 1 ]]; then
      replace_version() {
         mkdir -p "$SYSROOT/var/db/minipkg/packages/$1"
         sed "s/^pkgver=.*\$/pkgver=$2/"                          \
            "files/var/db/minipkg/packages/$1/package.info"       \
            > "$SYSROOT/var/db/minipkg/packages/$1/package.info"
      }

      replace_version binutils      "$BINUTILS_VERSION"
      replace_version busybox       "$BUSYBOX_VERSION"
      replace_version gcc-stage1    "$GCC_VERSION"
      replace_version linux         "$KERNEL_VERSION"
      replace_version linux-headers "$KERNEL_VERSION"
      replace_version make          "$MAKE_VERSION"
      replace_version minipkg       "$MINIPKG_VERSION"
      replace_version $LIBC_NAME    "$LIBC_VERSION"
   fi
}

create_e2fs() {
   local mp
   mp="/mnt/micro-linux-rootfs"

   log "Creating ext2 image..."
   qcheck fallocate -l "$E2FS_SIZE" rootfs.ext2
   qcheck mke2fs rootfs.ext2
   sudo mkdir -p "${mp}"

   log "Mounting ext2 image..."
   sudo mount rootfs.ext2 "${mp}"
   
   log "Copying rootfs -> ext2 image..."
   qcheck sudo cp -ax rootfs/* "${mp}/"

   log "Changing owner to root..."
   qcheck sudo chown 0:0 -R "${mp}"

   log "Unmounting ext2 image..."
   sudo umount "${mp}"
}

strip_rootfs() {
   log "Stripping the rootfs..."
   for f in $(find "$SYSROOT/bin" -type f) $(find "$SYSROOT/usr/libexec" -type f); do
      "${CROSS}strip" "$f" &>/dev/null
   done
}

