#!/usr/bin/env bash

create_rootfs() {
   log "Creating a template rootfs..."

   # Create base directories.
   mkdir -p "${SYSROOT}"/{dev,etc,home,mnt,opt,root,run,srv,sys,tmp}
   mkdir -p "${SYSROOT}"/usr/{bin,include,lib,libexec,share,src}
   mkdir -p "${SYSROOT}"/var/{lock,log,spool,tmp}

   # Create symlinks.
   ln -sf . "${SYSROOT}/usr/local"
   ln -sf ../etc "${SYSROOT}/usr/etc"
   ln -sf lib "${SYSROOT}/usr/lib${BITS}"
   ln -sf usr/bin "${SYSROOT}/bin"
   ln -sf usr/sbin "${SYSROOT}/sbin"
   ln -sf usr/lib "${SYSROOT}/lib"
   ln -sf usr/lib "${SYSROOT}/lib${BITS}"

   # Change permissions.
   chmod 700 "${SYSROOT}/root"
   chmod 777 "${SYSROOT}/tmp"
   chmod 777 "${SYSROOT}/var/tmp"

   # Create device files.
   as_root mknod -m 600 "${SYSROOT}/dev/console"  c 5 1
   as_root mknod -m 666 "${SYSROOT}/dev/null"     c 1 3 
   as_root mknod -m 666 "${SYSROOT}/dev/zero"     c 1 5
   as_root mknod -m 666 "${SYSROOT}/dev/full"     c 1 7
}

