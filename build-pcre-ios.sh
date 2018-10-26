#!/bin/bash

#
# build PCRE for iOS and iOS simulator
#

# make sure this is not set
unset MACOSX_DEPLOYMENT_TARGET

# be ridiculously conservative with regard to ios features
export IPHONEOS_DEPLOYMENT_TARGET="7.0"

# exit on error
set -e

ME=`basename $0`
DIR=`pwd`
SDK_VER="12.0"
BUILDDIR="${DIR}/../prebuilt/${SDK_VER}-pcre-build"
DESTDIR="${DIR}/../prebuilt/ios"

if [ ! -f pcre_version.c ]; then
	echo
	echo "Cannot find pcre_version.c"
	echo "Run script from within pcre directory:"
	echo "pcre-8.31$ ../../../${ME}"
	echo
	exit
fi

mkdir -p ${BUILDDIR}        > /dev/null 2>&1
mkdir -p ${DESTDIR}/include > /dev/null 2>&1
mkdir -p ${DESTDIR}/lib     > /dev/null 2>&1

#
# Build for Device
#
if [ ! -f ${BUILDDIR}/device/lib/libpcre.a ]; then
  TOOLCHAIN_ROOT="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer" 
  SYSROOT="${TOOLCHAIN_ROOT}/SDKs/iPhoneOS${SDK_VER}.sdk"
  DEV_ARCHS="-arch armv7 -arch armv7s -arch arm64"
  export LDFLAGS="-isysroot ${SYSROOT} ${DEV_ARCHS} -lc++"

  if [ ! -d ${SYSROOT} ]; then
    echo
    echo "Cannot find iOS developer tools at ${SYSROOT}."
    echo
    exit  
  fi

  if [ -f Makefile ]; then
    make clean
  fi

  mkdir -p ${BUILDDIR}/device &> /dev/null

  ./configure \
  CFLAGS="-O -isysroot ${SYSROOT} ${DEV_ARCHS}" \
  CXXFLAGS="-O -isysroot ${SYSROOT} ${DEV_ARCHS}" \
  --disable-dependency-tracking \
  --host=arm-apple-darwin10 \
  --target=arm-apple-darwin10 \
  --disable-shared \
  --enable-utf8 \
  --prefix=${BUILDDIR}/device

  make -j4 install
else
  echo
  echo "${BUILDDIR}/device already exists - not rebuilding."
  echo
fi

#
# Simulator
#
if [ ! -f ${BUILDDIR}/simulator/lib/libpcre.a ]; then
  TOOLCHAIN_ROOT="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer" 
  SYSROOT="${TOOLCHAIN_ROOT}/SDKs/iPhoneSimulator${SDK_VER}.sdk"
  DEV_ARCHS="-arch x86_64"
  export LDFLAGS="-isysroot ${SYSROOT} ${DEV_ARCHS} -lc++"

  if [ ! -d ${SYSROOT} ]; then
    echo
    echo "Cannot find iOS developer tools at ${SYSROOT}."
    echo
    exit  
  fi

  if [ -f Makefile ]; then
  	make clean
  fi

  mkdir -p ${BUILDDIR}/simulator &> /dev/null

  ./configure \
  CFLAGS="-O -isysroot ${SYSROOT} -arch x86_64" \
  CXXFLAGS="-O -isysroot ${SYSROOT} -arch x86_64" \
  --host=x86_64-apple-darwin10 \
  --target=x86_64-apple-darwin10 \
  --disable-dependency-tracking \
  --disable-shared \
  --enable-utf8 \
  --prefix=${BUILDDIR}/simulator

  make -j4 install
else
  echo
  echo "${BUILDDIR}/device already exists - not rebuilding."
  echo
fi

cp ${BUILDDIR}/device/include/* ${DESTDIR}/include/

echo
echo "- Creating universal binaries --------------------------------------"
echo

LIBS=`find ${BUILDDIR}/device/ -name '*.a'`
set +e
for LIB in ${LIBS}; do
  LIBFN=`basename $LIB`
  lipo -create -output ${DESTDIR}/lib/${LIBFN} ${BUILDDIR}/simulator/lib/$LIBFN ${BUILDDIR}/device/lib/$LIBFN
done
