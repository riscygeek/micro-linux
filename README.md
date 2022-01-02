# Micro-Linux
Micro-Linux is a source-based Linux distribution focussed on providing
a simple means of building a minimal Linux system that can rebuild itself.

### Inspiration or Reason why this yet another Linux distribution exists
To test my [bcc](https://github.com/riscygeek/bcc) compiler on RISC-V I had to build a Linux system that could build bcc.
Before making Micro-Linux I at first decided to use [Buildroot](https://buildroot.org) but quickly found out
that Buildroot doesn't build a target-compiler. Therefore I was forced to cross-compile GCC.
In general using this method was rather cumbersome and took a long time.
Then I found out about the [Yocto project](https://www.yoctoproject.org) and tried it out, but I failed quickly to understand this complex project.
But then some day at the end of 2021 I watched a presentation about [Building the Simplest Possible Linux System](https://www.youtube.com/watch?v=Sk9TatW9ino)
and it inspired me to create a simple bootstrap script to build a tiny Linux distribution with only a few core-packages.

## Initial Packages
- [Linux](https://kernel.org) kernel
- [Busybox](https://busybox.net) (providing things like `ls`)
- [Binitils](https://www.gnu.org/software/binutils/) (for the assembler and linker)
- [GCC](https://www.gnu.org/software/gcc/) (for the compiler)
- [gmp](https://gmplib.org/), [mpc](http://www.multiprecision.org/mpc/) and [mpfr](https://www.mpfr.org/) (statically-linked runtime-dependencies for GCC)
- [GNU Make](https://www.gnu.org/software/make/)
- Either [musl](https://musl.libc.org/) or [glibc](https://www.gnu.org/software/libc/) (for the host C library)
- and [bash](https://www.gnu.org/software/bash/)
- [minipkg](minipkg) package manager (can be disabled with `--disable-minipkg`)

## Bootstrap process
```
./make.sh --target=TARGET --build
```

A comprehensive list of options can be found with `./make.sh --help`. \
If you are building for x86\_64 arch and intend to run the OS in [QEMU](https://www.qemu.org/)
then you can use the provided [kernel config](kconfig) with the option `--kernel-config=$PWD/kconfig`
and you can run QEMU with `./run.sh`. \
To build an ext2 filesystem either specify the `--enable-e2fs`
option the building or create it with: \
```
./make.sh --create-e2fs
```

## Package Manager
As of now (2021-01-02) Micro-Linux still uses version 1 of the minipkg package manager.
As soon as [minipkg2](https://github.com/riscygeek/minipkg2) has feature-parity,
this project will switch to using it.
