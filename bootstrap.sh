#!/usr/bin/env bash

# TODO: option parsing
MACH_TARGET="x86_64-micro-linux-musl"
MACH_BUILD="$(gcc -dumpmachine)"

topdir="$PWD"
srcdir="$topdir/src"
builddir="$topdir/build"
rootdir="$topdir/rootfs"
toolsdir="$topdir/tools"

export PATH="$toolsdir/bin:$PATH"
alias eminipkg2="check $toolsdir/bin/minipkg2 --root='$rootdir' --host='$MACH_TARGET'"
shopt -s expand_aliases

V_BINUTILS="2.36.1"
V_GCC="11.1.0"
V_MINIPKG2="0.1.2"
V_LINUX="5.16.2"

TAR_BINUTILS="binutils-${V_BINUTILS}.tar.gz"
TAR_GCC="gcc-${V_GCC}.tar.gz"
TAR_MINIPKG2="minipkg2-${V_MINIPKG2}.tar.gz"
TAR_LINUX="linux-${V_LINUX}.tar.xz"

#GNUFTP="https://ftp.gnu.org/gnu"
GNUFTP="https://ftpmirror.gnu.org/gnu"
URL_BINUTILS="$GNUFTP/binutils/$TAR_BINUTILS"
URL_GCC="$GNUFTP/gcc/gcc-${V_GCC}/$TAR_GCC"
URL_MINIPKG2="https://github.com/riscygeek/minipkg2/archive/refs/tags/v${V_MINIPKG2}.tar.gz"
URL_LINUX="https://mirrors.edge.kernel.org/pub/linux/kernel/v$(cut -d'.' -f1 <<<"$V_LINUX").x/$TAR_LINUX"

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
[[ $(cut -d. -f1 <<< "$V_LINUX") -lt 3 ]] && fail "Linux kernel version must be at least 3.0"

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

# Determine the kernel CPU architecture.
case "$MACH_TARGET"  in
i[3456]86-*|x86_64-*)
    KARCH="x86"
    ;;
arm-*|armv*-*|aarch64-*)
    KARCH="arm"
    ;;
riscv*-*)
    KARCH="riscv"
    ;;
*)
    fail "Failed to detect the kernel CPU architecture for '$MACH_TARGET'"
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
    fail "Failed to determne the bit-size of '$MACH_TARGET'"
    ;;
esac

rm -rf "$builddir"
mkdir -p "$srcdir" "$rootdir" "$builddir" "$toolsdir" || exit 1

_offline() {
symlink() { [[ -L "$2" ]] || check ln -sf "$1" "$2"; }
mkchardev() { [[ -c "$1" ]] || check sudo mknod -m "$2" "$1" c "$3" "$4"; }
check mkdir -p "$rootdir"/{boot,dev,etc,home,mnt,opt,proc,root,sys,tmp,usr}
check mkdir -p "$rootdir"/usr/{bin,include,lib,libexec,share,src}
check mkdir -p "$rootdir"/usr/local/{bin,etc,include,lib,libexec,share,src}
check mkdir -p "$rootdir"/var/{cache,db,lib,local,log,spool,tmp}
symlink ../etc          "$rootdir/usr/etc"
symlink lib             "$rootdir/lib$BITS"
symlink bin             "$rootdir/usr/sbin"
symlink usr/bin         "$rootdir/bin"
symlink usr/bin         "$rootdir/sbin"
symlink usr/lib         "$rootdir/lib"
symlink usr/lib         "$rootdir/lib$BITS"
symlink ../proc/mounts  "$rootdir/etc/mtab"

check touch         "$rootdir/var/log/lastlog"
check chmod 700     "$rootdir/root"
check chmod 1777    "$rootdir/tmp" "$rootdir/var/tmp"
check chmod 664     "$rootdir/var/log/lastlog"

mkchardev "$rootdir/dev/console"  600 5 1
mkchardev "$rootdir/dev/null"     666 1 3
mkchardev "$rootdir/dev/zero"     666 1 5
mkchardev "$rootdir/dev/full"     666 1 7
}

download "$URL_LINUX"       "$srcdir/$TAR_LINUX"
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

eminipkg2 repo --init "$URL_REPO"

eminipkg2 install -y filesystem

if [[ ! -d $rootdir/usr/include/linux ]]; then
    echo "Installing the kernel headers..."
    check tar -xf "$srcdir/$TAR_LINUX" -C "$builddir"
    epushd "$builddir/linux-$V_LINUX"
        cp "$topdir/kconfig" .config
        check make ARCH="$KARCH" mrproper
        check make ARCH="$KARCH" INSTALL_HDR_PATH="$rootdir/usr" headers_install
    epopd
fi

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
               --disable-nls                \
               --disable-multiblib          \
               --disable-bootstrap          \
               --disable-shared             \
               --disable-threads            \
               --disable-decimal-float      \
               --disable-libatomic          \
               --disable-libgomp            \
               --disable-libquadmath        \
               --disable-libssp             \
               --disable-libvtv             \
               --disable-libstdcxx

            check pmake
            check make install
        epopd
    epopd
fi

if [[ ! -f $rootdir/lib/libc.so ]]; then
    eminipkg2 install -y "$LIBC"
    _tmp2() {
    epushd "$builddir/$LIBC-$V_LIBC"
        case "$LIBC" in
        glibc)
            echo "Building glibc..."
            rm -rf build
            mkdir build || exit 1
            epushd build
                echo "rootsbindir=/usr/sbin" > configparms
                check ../configure                          \
                    --prefix=/usr                           \
                    --host="$MACH_TARGET"                   \
                    --build="$MACH_BUILD"                   \
                    --with-headers="$rootdir/usr/include"   \
                    --enable-kernel=3.2                     \
                    --disable-multilib                      \
                    libc_cv_slibdir=/usr/lib
                check pmake
                check make DESTDIR="$rootdir" install

                sed -i '/RTLDLIST=/s@/usr@@g' "$rootdir/usr/bin/ldd"
            epopd
            ;;
        musl)
            echo "Building musl..."
            check ./configure                               \
                CROSS_COMPILE="${MACH_TARGET}-"             \
                --prefix=/usr                               \
                --target="$MACH_TARGET"

            check pmake
            check make DESTDIR="$rootdir" install
            ;;
        *)
            fail "Unsupported C library '$LIBC'"
            ;;
        esac
    epopd
    }
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

eminipkg2 install -y busybox bash make binutils gcc
