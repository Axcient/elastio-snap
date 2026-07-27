#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only

SRC_DIR=$(dirname "$0")
FEATURE_TEST_DIR="$SRC_DIR/configure-tests/feature-tests"
FEATURE_TEST_FILES="$FEATURE_TEST_DIR/compiler.c"
KERNEL_VERSION=${1:-$(uname -r)}
MAKE_ENV_FILE=${2:-"elastio.env"}

function clean_feature_test_build {
    rm -rf "${FEATURE_TEST_DIR}/build"
    make -s -C $FEATURE_TEST_DIR clean KERNELVERSION=$KERNEL_VERSION
}

ln -sf /dev/null "$MAKE_ENV_FILE"
if [[ -f /etc/redhat-release ]]; then
    echo "Check compiler for redhat kernel-${KERNEL_VERSION} ..."
    clean_feature_test_build

    if make -C $FEATURE_TEST_DIR TEST_NAME=compiler KERNELVERSION=$KERNEL_VERSION; then
        echo "System compiler was passed"
        exit 0
    fi

    for toolset in $(ls -1 /opt/rh/gcc-toolset-*/enable); do
        clean_feature_test_build
        source ${toolset}
        if make -C $FEATURE_TEST_DIR TEST_NAME=compiler KERNELVERSION=$KERNEL_VERSION; then
            echo "Toolset ${toolset} was passed"
            ln -sf "${toolset}" "$MAKE_ENV_FILE"
            exit 0
        fi
    done

    GCC_MAJOR=$(sed -nE 's/CONFIG_GCC_VERSION=(.+)..../\1/p' "/boot/config-$KERNEL_VERSION")
    echo "Any toolset was not passed. Most probably need to install gcc-toolset-${GCC_MAJOR}. Trying compile without Wall."
    rm "$MAKE_ENV_FILE"
    echo "export COMPAT_OLD_GCC=y" > "$MAKE_ENV_FILE"
fi
