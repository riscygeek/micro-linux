

print_help() {
   echo "Automatic Linux System Builder."
   echo
   echo "Usage: $0 [OPTION]..."
   echo
   echo "Actions:"
   echo "  -h, --help                  Display this help and exit."
   echo "  --download                  Just download the dependencies."
   echo "  --build                     Build a rootfs."
   echo "  --build-toolchain           Just build the toolchain."
   echo "  --build-kernel              Just build the kernel."
   echo "  --clean                     Delete the rootfs and build directories."
   echo "  --clean-all                 Delete all non-source files."
   echo "  --create-e2fs               Just create an ext2 image and exit."
   echo
   echo "Configuration:"
   echo "  -v, --verbose               Don't suppress messages."
   echo "  -q, --quiet                 Invert --verbose."
   echo "  -jN, --jobs=N               The number of jobs to use for parallel make [$JOBS]."
   echo "  --target=TARGET             Cross-compile to run on TARGET."
   echo "  --kernel-version=VERSION    Specify the kernel version [$KERNEL_VERSION]."
   echo "  --busybox-version=VERSION   Specify the busybox version [$BUSYBOX_VERSION]."
   echo "  --binutils-version=VERSION  Specify the binutils version [$BINUTILS_VERSION]."
   echo "  --gcc-version=VERSION       Specify the gcc version [$GCC_VERSION]."
   echo "  --make-version=VERSION      Specify the make version [$MAKE_VERSION]."
   echo "  --libc-version=VERSION      Specify the libc version [musl: $MUSL_VERSION, glibc: $GLIBC_VERSION]."
   echo "  --bash-version=VERSION      Specify the bash version [$BASH_VERSION]."
   echo "  --iana-etc-version=VERSION  Specify the iana-etc version [$IANA_ETC_VERSION]."
   echo "  --gmp-version=VERSION       Specify the gmp version [$GMP_VERSION]."
   echo "  --mpc-version=VERSION       Specify the mpc version [$MPC_VERSION]."
   echo "  --mpfr-version=VERSION      Specify the mpfr versin [$MPFR_VERSION]."
   echo "  --kernel-defconfig=NAME     Specify the kernel defconfig."
   echo "  --kernel-config=CONFIG      Specify a kernel config."
   echo "  --save-kconfig[=PATH]       Save the kernel config."
   echo "  --busybox-config=CONFIG     Specify a busybox config."
   echo "  --save-bbconfig[=CONFIG]    Save the busybox config."
   echo "  --with-arch=ARCH            Gets passed to configure."
   echo "  --with-toolchain=PATH       Use a different toolchain [$TOOLS]."
   echo
   echo "Features:"
   echo "  --disable-native-toolchain  Don't build a native toolchain."
   echo "  --disable-kernel            Don't build a kernel."
   echo "  --disable-bash              Don't build the Bourne Again Shell."
   echo "  --disable-iana-etc          Don't install the iana-etc package."
   echo "  --disable-minipkg           Don't install the minipkg package manager."
   echo "  --enable-man-pages          Install the man-pages package."
   echo "  --disable-menuconfig        Don't show the menuconfig when building with defconfig."
   echo "  --enable-e2fs               Create an ext2 image."
   echo "  --enable-strip              Remove debug symbols in the rootfs."
   echo
   echo "Some influential environment variables:"
   echo "  CC          C compiler command."
   echo "  CPP         C/C++ preprocessor."
   echo "  CXX         C++ compiler command."
   echo "  CFLAGS      C compiler flags."
   echo "  CPPFLAGS    C/C++ preprocessor flags."
   echo "  CXXFLAGS    C++ compiler flags."
   echo "  LDFLAGS     Linker flags."
   echo "  LIBS        Libraries to pass to the linker."

   exit 0
}

parse_cmdline_args() {
   get_arg() {
      eval "$1='$(sed 's/^[^=]\+=//' <<< "$2")'"
   }

   while [[ $@ ]]; do
      case "$1" in
      -h|--help)
         print_help
         ;;
      --clean)
         log "Cleaning old directories..."
         sudo rm -rf "$SYSROOT"
         rm -rf "build"
         rm -f rootfs.ext2
         ;;
      --clean-all)
         log "Cleaning old directories..."
         sudo rm -rf "$SYSROOT"
         rm -rf "build" "tools"
         rm -f rootfs.ext2
         ;;
      --download)
         DO_BUILD=d
         ;;
      --build)
         DO_BUILD=a
         ;;
      --build-toolchain)
         DO_BUILD=t
         ;;
      --build-kernel)
         DO_BUILD=k
         ;;
      -v|--verbose)
         VERBOSE=1
         ;;
      -q|--quiet)
         VERBOSE=0
         ;;
      -j)
         JOBS="$2"
         shift
         ;;
      -j*)
         JOBS="$(sed 's/^-j//' <<< "$1")"
         ;;
      --jobs=*)
         get_arg JOBS "$1"
         ;;
      --target=*)
         get_arg TARGET "$1"
         ;;
      --kernel-version=*)
         get_arg KERNEL_VERSION "$1"
         ;;
      --busybox-version=*)
         get_arg BUSYBOX_VERSION "$1"
         ;;
      --binutils-version=*)
         get_arg BINUTILS_VERSION "$1"
         ;;
      --gcc-version=*)
         get_arg GCC_VERSION "$1"
         ;;
      --gmp-versio=*)
         get_arg GMP_VERSION "$1"
         ;;
      --mpc-version=*)
         get_arg MPC_VERSION "$1"
         ;;
      --mpfr-version=*)
         get_arg MPFR_VERSION "$1"
         ;;
      --make-version=*)
         get_arg MAKE_VERSION "$1"
         ;;
      --libc-version=*)
         get_arg LIBC_VERSION "$1"
         ;;
      --bash-version=*)
         get_arg BASH_VERSION "$1"
         ;;
      --kernel-defconfig=*)
         get_arg KERNEL_DEFCONFIG "$1"
         ;;
      --kernel-config=*)
         get_arg KERNEL_CONFIG "$1"
         ;;
      --save-kconfig)
         KERNEL_SAVE_TO="-"
         ;;
      --save-kconfig)
         get_arg KERNEL_SAVE_TO "$1"
         ;;
      --busybox-config=*)
         get_arg BUSYBOX_CONFIG "$1"
         ;;
      --save-bbconfig)
         BUSYBOX_SAVE_TO="-"
         ;;
      --save-bbconfig=*)
         get_arg BUSYBOX_SAVE_TO "$1"
         ;;
      --with-arch=*)
         get_arg WITH_ARCH "$1"
         ;;
      --with-cpu=*)
         get_arg WITH_CPU "$1"
         ;;
      --with-toolchain=*)
         get_arg TOOLS "$1"
         check_cross_gcc
         ;;
      --enable-native-toolchain)
         ENABLE_NATIVE_TOOLCHAIN=1
         ;;
      --disable-native-toolchain)
         ENABLE_NATIVE_TOOLCHAIN=0
         ;;
      --enable-kernel)
         ENABLE_KERNEL=1
         ;;
      --disable-kernel)
         ENABLE_KERNEL=0
         ;;
      --enable-bash)
         ENABLE_BASH=1
         ;;
      --disable-bash)
         ENABLE_BASH=0
         ;;
      --enable-menuconfig)
         ENABLE_MENUCONFIG=1
         ;;
      --disable-menuconfig)
         ENABLE_MENUCONFIG=0
         ;;
      --enable-e2fs)
         ENABLE_E2FS=1
         ;;
      --disable-e2fs)
         ENABLE_E2FS=0
         ;;
      --enable-iana-etc)
         ENABLE_IANA_ETC=1
         ;;
      --disable-iana-etc)
         ENABLE_IANA_ETC=0
         ;;
      --enable-man-pages)
         ENABLE_MAN_PAGES=1
         ;;
      --disable-man-pages)
         ENABLE_MAN_PAGES=0
         ;;
      --enable-strip)
         ENABLE_STRIP=1
         ;;
      --disable-strip)
         ENABLE_STRIP=0
         ;;
      --enable-minipkg)
         ENABLE_MINIPKG=1
         ;;
      --disable-minipkg)
         ENABLE_MINIPKG=0
         ;;
      --create-e2fs)
         create_e2fs
         exit
         ;;
      --e2fs-size=*)
         get_arg E2FS_SIZE "$1"
         ;;
      -*)
         fail "invalid option: $1"
         ;;
      *)
         fail "invalid argument: $1"
         ;;
      esac
      shift
   done

   # Check for invalid configuration options.
   [[ $KERNEL_SAVE_TO = - && -z $KERNEL_CONFIG ]] && fail "--save-kconfig must be provided with an argument."
   [[ $BUSYBOX_SAVE_TO = - && -z $BUSYBOX_CONFIG ]] && fail "--save-bbconfig must be provided with an argument."
}
