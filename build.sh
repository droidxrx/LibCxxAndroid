#!/bin/bash

SCRIPTDIR=$(cd "$(realpath "$(dirname "$0")")"; pwd)

export CCACHE_DIR=${SCRIPTDIR}/.cache
CMAKE_BUILD_DIR="$SCRIPTDIR/build"
CMAKE_INSTALL_PREFIX="$SCRIPTDIR/dist"
CMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake
OUTPUT_ARCHIVE="$SCRIPTDIR/LibC++Android.tar.gz"

build_lib() {
    rm -rf "$CMAKE_BUILD_DIR" "$CMAKE_INSTALL_PREFIX"

    cmake -G "Ninja" -S $SCRIPTDIR -B "$CMAKE_BUILD_DIR" \
        -DCMAKE_TOOLCHAIN_FILE="${CMAKE_TOOLCHAIN_FILE}" \
        -DANDROID_PLATFORM="24" \
        -DANDROID_STL="none" \
        -DCMAKE_BUILD_TYPE="Release" \
        -DCMAKE_SYSTEM_NAME="Android" \
        -DCMAKE_INSTALL_PREFIX="$CMAKE_INSTALL_PREFIX"

    if [ "$?" != "0" ]; then
        echo "Failed Generate CMake config"
        exit 1
    fi

    cmake --build "$CMAKE_BUILD_DIR" -j 10 --config Release --target install
    if [ "$?" != "0" ]; then
        echo "Build failed"
        exit 1
    fi
}

cd $SCRIPTDIR

build_lib

cd $CMAKE_INSTALL_PREFIX

rm -rf $OUTPUT_ARCHIVE
GZIP=-9 tar -czf $OUTPUT_ARCHIVE ./