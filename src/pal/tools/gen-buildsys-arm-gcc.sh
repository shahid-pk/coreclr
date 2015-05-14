#!/usr/bin/env bash
#
# This file invokes cmake and generates the build system for gcc.
#

# Set up the environment to be used for building with clang.
export CC="$(arm-linux-androideabi-gcc)"
export CXX="$(arm-linux-androideabi-g++)"

# Possible build types are DEBUG, RELEASE, RELWITHDEBINFO, MINSIZEREL.
# Default to DEBUG
if [ -z "$3" ]
then
  echo "Defaulting to DEBUG build."
  buildtype="DEBUG"
else
  buildtype="$3"
fi

arm_gcc_ar="$(which arm-linux-androideabi-ar)"
[[ $? -eq 0 ]] || { echo "Unable to locate ar"; exit 1; }
arm_gcc_link="$(which arm-linux-androideabi-ld)"
[[ $? -eq 0 ]] || { echo "Unable to locate arm-linux-androideabi-ld"; exit 1; }
arm_gcc_nm="$(which arm-linux-androideabi-nm)"
[[ $? -eq 0 ]] || { echo "Unable to locate arm-linux-androideabi-nm"; exit 1; }
arm_gcc_ranlib="$(which arm-linux-androideabi-ranlib)"
[[ $? -eq 0 ]] || { echo "Unable to arm-linux-androideabi-ranlib"; exit 1; }
if [ $OS = "Linux" -o $OS = "FreeBSD" -o $OS = "OpenBSD" -o $OS = "NetBSD" ]; then
  arm_gcc_objdump="$(which arm-linux-androideabi-objdump)"
  [[ $? -eq 0 ]] || { echo "Unable to locate arm-linux-androideabi-objdump"; exit 1; }
fi

cmake_extra_defines=
if [[ -n "$LLDB_LIB_DIR" ]]; then
    cmake_extra_defines="$cmake_extra_defines -DWITH_LLDB_LIBS=$LLDB_LIB_DIR"
fi
if [[ -n "$LLDB_INCLUDE_DIR" ]]; then
    cmake_extra_defines="$cmake_extra_defines -DWITH_LLDB_INCLUDES=$LLDB_INCLUDE_DIR"
fi
  
cmake \
  "-DCMAKE_USER_MAKE_RULES_OVERRIDE=$1/src/pal/tools/clang-compiler-override.txt" \
  "-DCMAKE_AR=$arm_gcc_ar" \
  "-DCMAKE_LINKER=$arm_gcc_link" \
  "-DCMAKE_NM=$arm_gcc_nm" \
  "-DCMAKE_OBJDUMP=$arm_gcc_objdump" \
  "-DCMAKE_RANLIB=$arm_gcc_ranlib" \
  "-DCMAKE_BUILD_TYPE=$buildtype" \
  $cmake_extra_defines \
  "$1"
