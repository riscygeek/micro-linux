#!/bin/sh

TARGET="$(gcc -dumpmachine)"
VERSION="$(gcc -dumpversion)"

rm -rf "gcc-${VERSION}"

cd /usr/src
tar -xf "gcc-${VERSION}.tar.gz" || exit 1
cd "gcc-$VERSION"

mkdir -v build
cd build

# Configure libstdc++v3
../libstdc++-v3/configure		\
  CXXFLAGS="-g -O2 -D_GNU_SOURCE"	\
  --prefix=/usr				\
  --enable-silent-rules			\
  --disable-nls				\
  --disable-multilib			\
  --host="$TARGET"			\
  --disable-libstdcxx-pch		\
  || exit 1

# Build libstdc++v3
make || exit 1

# Install libstdc++v3
make install || exit 1

# Check the compiler

echo '#include <iostream>' 		>  /tmp/test.cpp
echo 'int main() {'			>> /tmp/test.cpp
echo '  std::cout << "Hello World\n";'	>> /tmp/test.cpp
echo '}'				>> /tmp/test.cpp

g++ -o /tmp/test /tmp/test.cpp		|| exit 1

[ "$(/tmp/test)" = "Hello World" ]	|| { echo "Invalid output"; exit 1; }

# Clean-up
rm -f /tmp/test /tmp/test.c
rm -rf /usr/src/gcc-${VERSION}.tar.gz
