#!/bin/bash

set -euo pipefail

KERNEL_SRC_DIR=$1
BUILD_DIR=$2
KERNEL_VERSION=$3

function fail() {
	echo "elastio-snap DKMS build error: $*" >&2
	exit 1
}

function get_kernel_gcc_major() {
	local _get_major_regax="(?i)\b[\w-]*gcc[\w-]*\b(?:\s*\([^)]+\))?\s+\K\d+(?=\.\d+\.\d+)"
	echo $(grep -oP "$_get_major_regax" /proc/version | tail -1)
}

function get_current_gcc_major() {
	gcc -dumpfullversion -dumpversion 2>/dev/null | sed -n 's/^\([0-9][0-9]*\)\..*/\1/p' | head -n 1
}

function enable_matching_toolset() { ## think about this part
	local _target_major=$1
	local _enable_script="/opt/rh/gcc-toolset-$_target_major}/enable"

	if [ -f "$_enable_script" ]; then
		. "$_enable_script"
		return 0
	fi
	return 1
}

function main() {
	local _kernel_gcc=$(get_kernel_gcc_major || true)
	local _cur_gcc=$(get_current_gcc_major || true)

	if [[ -z $_kernel_gcc || -z $_cur_gcc ]]; then
		echo "kernel gcc major: '$_kernel_gcc'"
		echo "local gcc major: '$_cur_gcc'"
		fail "could not determine kernel or local gcc version(s)"
	fi

	if [[ $_cur_gcc -lt $_kernel_gcc ]]; then
		enable_matching_toolset "$_kernel_gcc" || \
		fail "minimum GCC version '$_kernel_gcc' is required to build elastio-snap for this kernel($KERNEL_VERSIION)!"
	fi
	echo "getting current gcc version to make sure it works"
	gcc --version
	#exec make -C "$KERNEL_SRC_DIR" M="$BUILD_DIR" KVER="$KERNEL_VERSION" modules
}

main
