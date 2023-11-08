#!/bin/bash

echo "Running the Axcient Kernel Module signer"

result=$(mokutil --sb-state)
if [[ "$result" != *"enabled"* ]]; then
    echo "Detected a BIOS firmware or the Secure Boot feature is disabled"
    exit 1
else 
    keys=$(cat /proc/keys | grep "asymmetri Axcient")
    if [ -n "$keys" ]; then 
	echo "Starting the setup"
    else
	echo "WARNING: Secure Boot detected on this system. Either disable EFI Secure Boot "
	"or check with Axcient knowledgebase for instructions "
	"for enrolling a signing key for secure DKMS module support." >&2 \
	&& exit 0
    fi	
fi

echo "Kernel Version: ${1}"
echo "Module Path: ${2}"

hash_algo=sha256
private_key=/root/axcient-driver.key
x509_cert=/root/axcient-driver.der

if [  -n "$(uname -a | grep Ubuntu)" ]; then
       prefix=/usr/src/linux-headers-
else
       prefix=/usr/src/kernels/
fi

"${prefix}${1}/scripts/sign-file" \
    "${hash_algo}" "${private_key}" "${x509_cert}" "${2}" \
    && echo "Signed newly-built module ${2} with MOK successfully." >&2 \
    && exit 0
echo "Error signing file ${2}." >&2
exit 1

