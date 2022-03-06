#!/usr/bin/env bash

# TODO: option parsing
MACH_TARGET="$(uname -m)-micro-linux-musl"
MACH_BUILD="$(gcc -dumpmachine)"
BRANCH="unstable"

topdir="$PWD"
srcdir="$topdir/src"
builddir="$topdir/build"
rootdir="$topdir/rootfs"
toolsdir="$topdir/tools"

export PATH="$toolsdir/bin:$PATH"
alias eminipkg2="check $toolsdir/bin/minipkg2 --root='$rootdir'"
alias ecminipkg2="eminipkg2 --host='$MACH_TARGET'"
shopt -s expand_aliases

V_BINUTILS="2.37"
V_GCC="11.2.0"
V_MINIPKG2="0.4.7"

TAR_BINUTILS="binutils-${V_BINUTILS}.tar.gz"
TAR_GCC="gcc-${V_GCC}.tar.gz"
TAR_MINIPKG2="minipkg2-${V_MINIPKG2}.tar.gz"

#GNUFTP="https://ftp.gnu.org/gnu"
GNUFTP="https://ftpmirror.gnu.org/gnu"
URL_BINUTILS="$GNUFTP/binutils/$TAR_BINUTILS"
URL_GCC="$GNUFTP/gcc/gcc-${V_GCC}/$TAR_GCC"
URL_MINIPKG2="https://github.com/riscygeek/minipkg2/archive/refs/tags/v${V_MINIPKG2}.tar.gz"

URL_REPO="https://github.com/riscygeek/micro-linux-repo"

fail() { echo "$@" >&2; exit 1; }

# Check if a program is installed.
has() { which "$1" &>/dev/null; }

# Fail if a dependency is not installed.
check_dep() { has "$1" || fail "$1 is not installed"; }

# Download a file from $2 and put it in $1.
download() { [[ -f $2 ]] || curl -Lo "$2" "$1" || { rm -f "$2"; fail "Failed to download '$2' from '$1'"; }; }

# Error-checking versions of pushd/popd.
epushd() { builtin pushd "$1" >/dev/null || exit 1; }
epopd() { builtin popd >/dev/null || exit 1; }

# Run a command and fail if it fails.
check() { "$@" || fail "Failed to execute '$@'"; }

# Parallel make.
pmake() { make -j$(nproc); }

check_dep "which"
check_dep "make"
check_dep "curl"
check_dep "gcc"
check_dep "meson"
check_dep "git"

# Check the kernel version.

# Determine the C library.
case "$MACH_TARGET" in
*-gnu*)
    LIBC="glibc"
    V_LIBC="$V_GLIBC"
    TAR_LIBC="$TAR_GLIBC"
    URL_LIBC="$URL_GLIBC"
    ;;
*-musl*)
    LIBC="musl"
    V_LIBC="$V_MUSL"
    TAR_LIBC="$TAR_MUSL"
    URL_LIBC="$URL_MUSL"
    ;;
*)
    fail "Failed to detect C library for '$MACH_TARGET'"
    ;;
esac


# Determine the bit-size
case "$MACH_TARGET" in
i[3456]86-*|arm-*|armv*-*|riscv32-*)
    BITS=32
    ;;
x86_64-*|aarch64-*|riscv64-*)
    BITS=64
    ;;
*)
    fail "Failed to determine the bit-size of '$MACH_TARGET'"
    ;;
esac

rm -rf "$builddir"
mkdir -p "$srcdir" "$rootdir" "$builddir" "$toolsdir" || exit 1

download "$URL_BINUTILS"    "$srcdir/$TAR_BINUTILS"
download "$URL_GCC"         "$srcdir/$TAR_GCC"
download "$URL_MINIPKG2"    "$srcdir/$TAR_MINIPKG2"

if [[ ! -f $toolsdir/bin/minipkg2 ]]; then
    echo "Building build-minipkg2..."
    check tar -xf "$srcdir/$TAR_MINIPKG2" -C "$builddir"
    epushd "$builddir/minipkg2-$V_MINIPKG2"
        check meson setup build
        check meson configure build -Dprefix="$toolsdir"
        check meson compile -C build
        check meson install -C build
    epopd
fi

if [[ -d $rootdir/var/db/minipkg2/repo ]]; then
    echo "Synchronizing the minipkg2 repository..."
    eminipkg2 repo --sync
else
    echo "Initializing the minipkg2 repository..."
    eminipkg2 repo --branch "$BRANCH" --init "$URL_REPO"
fi

eminipkg2 install -y -s filesystem

if ! has "${MACH_TARGET}-as"; then
    echo "Building the cross-binutils..."
    check tar -xf "$srcdir/$TAR_BINUTILS" -C "$builddir"
    epushd "$builddir/binutils-$V_BINUTILS"
        rm -rf build
        mkdir build || exit 1
        epushd build
            check ../configure              \
                --prefix="$toolsdir"        \
                --host="$MACH_BUILD"        \
                --target="$MACH_TARGET"     \
                --with-sysroot="$rootdir"   \
                --disable-nls               \
                --disable-multilib          \
                --disable-werror

            check pmake
            check make install
        epopd
    epopd
fi

if ! has "${MACH_TARGET}-gcc"; then
    BUILD_CCC=1
    echo "Building the stage-1 cross-gcc..."
    check tar -xf "$srcdir/$TAR_GCC" -C "$builddir"
    epushd "$builddir/gcc-$V_GCC"
        check ./contrib/download_prerequisites
        rm -rf build
        mkdir build || exit 1
        epushd build
            check ../configure              \
                --prefix="$toolsdir"        \
                --host="$MACH_BUILD"        \
                --target="$MACH_TARGET"     \
                --with-sysroot="$rootdir"   \
                --with-newlib               \
                --without-headers           \
                --enable-languages=c        \
                --enable-initfini-array     \
                --disable-nls               \
                --disable-multiblib         \
                --disable-bootstrap         \
                --disable-shared            \
                --disable-threads           \
                --disable-decimal-float     \
                --disable-libatomic         \
                --disable-libgomp           \
                --disable-libquadmath       \
                --disable-libssp            \
                --disable-libvtv            \
                --disable-libstdcxx

            check pmake
            check make install
        epopd
    epopd
fi

if [[ ! -f $rootdir/lib/libc.so ]]; then
    ecminipkg2 install -y "$LIBC"
fi

if [[ $BUILD_CCC = 1 ]]; then
    echo "Building the final cross-compiler..."
    [[ -d $builddir/gcc-$V_GCC ]] || check tar -xf "$srcdir/$TAR_GCC" -C "$builddir"
    rm -rvf "$builddir/gcc-$V_GCC/build"
    mkdir "$builddir/gcc-$V_GCC/build" || exit 1
    epushd "$builddir/gcc-$V_GCC/build"
        check ../configure                  \
            --prefix="$toolsdir"            \
            --host="$MACH_BUILD"            \
            --target="$MACH_TARGET"         \
            --with-sysroot="$rootdir"       \
            --enable-languages=c,c++        \
            --disable-nls                   \
            --disable-shared                \
            --disable-multilib              \
            --disable-libsanitizer          \
            --disable-libstdcxx-pch         \
            --disable-bootstrap

        check pmake
        check make install
    epopd
fi

ecminipkg2 install -y -s tmp-{busybox,binutils,gcc,make,bash,minipkg2}

eminipkg2 download -y --deps --skip-installed tmp-libstdcxx busybox bash binutils gcc make minipkg2

cat <<EOF >"$rootdir/root/chroot-script.sh"
#!/tools/bin/bash -e

v="-v"

# Setup the environment.
export PATH=/tools/bin:/usr/bin
ln -sf $v /tools/bin/ash /bin/sh

# Complete the installation of the temporary toolchain.
minipkg2 install $v -y -s tmp-libstdcxx

# Create the final system toolchain.
minipkg2 install $v -y -s busybox bash binutils gcc make
ln -sf $v ash /bin/sh

export PATH=/usr/bin:/tools/bin

# Build the system package manager.
minipkg2 install $v -s -y minipkg2

export PATH=/usr/bin

# Clean up
minipkg2 remove $v -y tmp-{busybox,bash,binutils,gcc,make,libstdcxx,minipkg2}
minipkg2 clean $v
rm $v /root/chroot-script.sh
EOF
check chmod +x "$rootdir/root/chroot-script.sh"

umount_rootfs() {
    pushd "$rootdir"
        echo "Unmounting rootfs"
        check sudo umount -R proc
        check sudo umount -R dev
        check sudo umount -R sys
    popd
}

trap umount_rootfs EXIT

check sudo mount --types proc /proc "$rootdir/proc"
check sudo mount --rbind /sys "$rootdir/sys"
check sudo mount --rbind /dev "$rootdir/dev"
check sudo mount --make-rslave "$rootdir/sys"
check sudo mount --make-rslave "$rootdir/dev"

check sudo chroot "$rootdir" /root/chroot-script.sh

trap - EXIT
umount_rootfs

check sudo chown -R 0:0 "$rootdir"

echo "*** Installation finished ***"
