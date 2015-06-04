#!/usr/bin/env bash
#
# This file invokes cmake and generates the build system for gcc.
#

# Set up the environment to be used for building with clang.
export CC="$(which arm-linux-gnueabihf-gcc)"
export CXX="$(which arm-linux-gnueabihf-g++)"

# Possible build types are DEBUG, RELEASE, RELWITHDEBINFO, MINSIZEREL.
# Default to DEBUG
if [ -z "$2" ]
then
  echo "Defaulting to DEBUG build."
  buildtype="DEBUG"
else
  buildtype="$2"
fi

arm_gcc_ar="$(which arm-linux-gnueabihf-ar)"
[[ $? -eq 0 ]] || { echo "Unable to locate arm-linux-gnueabihf-ar"; exit 1; }
arm_gcc_link="$(which arm-linux-gnueabihf-ld)"
[[ $? -eq 0 ]] || { echo "Unable to locate arm-linux-gnueabihf-ld"; exit 1; }
arm_gcc_nm="$(which arm-linux-gnueabihf-nm)"
[[ $? -eq 0 ]] || { echo "Unable to locate arm-linux-gnueabihf-nm"; exit 1; }
arm_gcc_ranlib="$(which arm-linux-gnueabihf-ranlib)"
[[ $? -eq 0 ]] || { echo "Unable to locate arm-linux-gnueabihf-ranlib"; exit 1; }
if [ $OS = "Linux" -o $OS = "FreeBSD" -o $OS = "OpenBSD" -o $OS = "NetBSD" ]; then
  arm_gcc_objdump="$(which arm-linux-gnueabihf-objdump)"
  [[ $? -eq 0 ]] || { echo "Unable to locate arm-linux-gnueabihf-objdump"; exit 1; }
fi

cmake_extra_defines=
if [[ -n "$LLDB_LIB_DIR" ]]; then
    cmake_extra_defines="$cmake_extra_defines -DWITH_LLDB_LIBS=$LLDB_LIB_DIR"
fi
if [[ -n "$LLDB_INCLUDE_DIR" ]]; then
    cmake_extra_defines="$cmake_extra_defines -DWITH_LLDB_INCLUDES=$LLDB_INCLUDE_DIR"
fi
  
cmake \
  "-DCMAKE_USER_MAKE_RULES_OVERRIDE=$1/src/pal/tools/gcc-compiler-override.txt" \
  "-DCMAKE_AR=$arm_gcc_ar" \
  "-DCMAKE_LINKER=$arm_gcc_link" \
  "-DCMAKE_NM=$arm_gcc_nm" \
  "-DCMAKE_OBJDUMP=$arm_gcc_objdump" \
  "-DCMAKE_RANLIB=$arm_gcc_ranlib" \
  "-DCMAKE_BUILD_TYPE=$buildtype" \
  $cmake_extra_defines \
  "$1"
