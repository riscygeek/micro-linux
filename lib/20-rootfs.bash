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

   # Change permissions.
   check chmod 700 "${SYSROOT}/root"
   check chmod 777 "${SYSROOT}/tmp"
   check chmod 777 "${SYSROOT}/var/tmp"

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
   log "Creating system-configuration files..."

   for f in $(ls files); do
      cp -r "files/$f" "$SYSROOT"
   done
}

create_e2fs() {
   local mp
   mp="/mnt/micro-linux-rootfs"

   log "Creating ext2 image..."
   qcheck fallocate -l 2G rootfs.ext2
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
