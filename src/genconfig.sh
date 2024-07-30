#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only

# ./genconfig.sh - generate C header for setting the correct preprocessor definitions for the kernel version
# Usage ./genconfig.sh <kernel version> <make flags>
# The make flags are used for determining concurrency for the feature tests, it pulls out the value of the -j flag.
# ./genconfig.sh `uname -r` "-j4", four threads for running feature tests
# ./genconfig.sh `uname -r` "-i -j4 -d", doesn't care about other flags present

SRC_DIR=$(dirname "$0")
OUTPUT_FILE=$SRC_DIR/kernel-config.h
FEATURE_TEST_DIR="$SRC_DIR/configure-tests/feature-tests"
FEATURE_TEST_FILES="$FEATURE_TEST_DIR/*.c"
SYMBOL_TESTS_FILE="$SRC_DIR/configure-tests/symbol-tests"
CONFIG_TESTS_FILE="$SRC_DIR/configure-tests/config-tests"
KERNEL_VERSION=$(uname -r)
MAX_THREADS=$(echo "$2" | sed -E 's/.*-j\s*([0-9]+).*/\1/')
if ! [[ "$MAX_THREADS" =~ '^[0-9]+$' ]]; then # if there was no -j flag provided, default to the number of processors
	MAX_THREADS=$(getconf _NPROCESSORS_ONLN)
fi

if [ ! -z "$1" ]; then
	KERNEL_VERSION="$1"
fi

# As a fallback mechanism, if System.map is not found, download
# the debug linux kernel package and extract it from there
extract_system_map() {
	LINUX_IMAGE_DBG="linux-image-$KERNEL_VERSION-dbg"
	URL=$(sudo apt-get download --print-uris linux-image-$KERNEL_VERSION-dbg | awk -F\' {'print $2'})
	echo "Downloading $LINUX_IMAGE_DBG from $URL..."
	if ! wget -q "$URL"; then
		return 1
	fi

	echo "Unpacking..."
	ar x linux-image-$KERNEL_VERSION-dbg*.deb
	rm -f control.tar.xz linux-image-$KERNEL_VERSION-dbg*.deb debian-binary

	echo "Processing. This may take a while..."
	tar -xvf data.tar.xz -C / "./usr/lib/debug/boot/System.map-$KERNEL_VERSION"
	rm -f data.tar.xz
	echo "Done."

	[ -f "$SYSTEM_MAP_FILE" ] && return 0 || return 1
}

SYSTEM_MAP_FILE="/lib/modules/${KERNEL_VERSION}/System.map"

# Use standard location at the /boot
[ ! -f "$SYSTEM_MAP_FILE" ] && SYSTEM_MAP_FILE="/boot/System.map-${KERNEL_VERSION}"
if [ ! -f "$SYSTEM_MAP_FILE" ] || [ $(cat "$SYSTEM_MAP_FILE" | wc -l) -lt 10 ]; then
	# File /boot/System.map-${KERNEL_VERSION} exists, but it contains just a single line on Debian 11+.
	# Package linux-image-$(uname -r)-dbg installs normal map file.
	SYSTEM_MAP_FILE="/usr/lib/debug/boot/System.map-${KERNEL_VERSION}"

	if [ ! -f "$SYSTEM_MAP_FILE" ]; then
		# Obtain the relevant System.map file from the
		# dbg package if the package is being upgraded
		if [ "$(uname -r)" != "$KERNEL_VERSION" ]; then
			echo "No System.map found, trying to extract it from the *.deb package"
			if [ -f /etc/debian_version ] && ! extract_system_map; then
				exit 1
			fi
		else
			# If this is not an upgrade, fallback to kallsyms
			SYSTEM_MAP_FILE="/proc/kallsyms"
			if [ "$EUID" -ne 0 ]; then
				echo "Run 'make' command as sudo or root. Otherwise it is not possible to get addresses from the $SYSTEM_MAP_FILE"
				exit 1
			fi
		fi
	fi
fi

echo "generating configurations for kernel-${KERNEL_VERSION}"


rm -rf "${FEATURE_TEST_DIR}/build"
rm -f $OUTPUT_FILE

echo "//The values in this file should be generated by the build process. Do not alter." >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE
echo "#ifndef ELASTIO_SNAP_KERNEL_CONFIG_H" >> $OUTPUT_FILE
echo "#define ELASTIO_SNAP_KERNEL_CONFIG_H" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

make -s -C $FEATURE_TEST_DIR clean KERNELVERSION=$KERNEL_VERSION

run_one_test() {
	local TEST="$(basename $1 .c)"
	local OBJ="$TEST.o"
	local MACRO_NAME="HAVE_$(echo ${TEST} | awk '{print toupper($0)}')"
	local PREFIX="performing configure test: $MACRO_NAME -"
	if make -C $FEATURE_TEST_DIR OBJ=$OBJ KERNELVERSION=$KERNEL_VERSION &>/dev/null ; then
		echo "$PREFIX present"
		echo "#define $MACRO_NAME" >> $OUTPUT_FILE
	else
		echo "$PREFIX not present"
	fi
}
export -f run_one_test
export FEATURE_TEST_DIR
export KERNEL_VERSION
export OUTPUT_FILE

ls -1 -q $FEATURE_TEST_FILES | xargs -P "$MAX_THREADS" -d"\n" -n1 -I {} bash -c 'run_one_test {}'

make -s -C $FEATURE_TEST_DIR clean KERNELVERSION=$KERNEL_VERSION

while read SYMBOL_NAME; do
	if [ -z "$SYMBOL_NAME" ]; then
		continue
	fi

	echo "performing $SYMBOL_NAME lookup"
	MACRO_NAME="$(echo ${SYMBOL_NAME} | awk '{print toupper($0)}')_ADDR"
	SYMBOL_ADDR=$(grep " ${SYMBOL_NAME}$" "${SYSTEM_MAP_FILE}" | awk '{print $1}')
	if [ -z "$SYMBOL_ADDR" ]; then
		SYMBOL_ADDR="0"
	fi
	echo "#define $MACRO_NAME 0x$SYMBOL_ADDR" >> $OUTPUT_FILE
done < $SYMBOL_TESTS_FILE

SYSTEM_CONFIG_FILE="/boot/config-$KERNEL_VERSION"
while read CONFIG_OPTION; do
	if [ -z "$CONFIG_OPTION" ]; then
		continue
	fi

	echo "checking $CONFIG_OPTION"
	MACRO_NAME="$(echo ${CONFIG_OPTION} | awk '{print toupper($0)}')"
	CONFIG_VALUE=$(grep "${CONFIG_OPTION}" "${SYSTEM_CONFIG_FILE}" | awk -F"=" '{print $2}')
	if [ -n "$CONFIG_VALUE" ]; then
		echo "#define $MACRO_NAME $CONFIG_VALUE" >> $OUTPUT_FILE
	fi
done < $CONFIG_TESTS_FILE

echo "" >> $OUTPUT_FILE
echo "#endif" >> $OUTPUT_FILE
