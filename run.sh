#!/bin/sh

qemu-system-x86_64               \
   -accel kvm -smp cores=4 -m 8G \
   -kernel rootfs/boot/vmlinuz   \
   -hda rootfs.ext2              \
   -nographic                    \
   -append "earlyprintk console=ttyS0 root=/dev/sda"

