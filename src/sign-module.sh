#!/bin/bash

echo "Running the Axcient Kernel Module signer"

result=$(mokutil --sb-state)
if [[ "$result" != *"enabled"* ]]; then
    echo "Detected a BIOS firmware or the Secure Boot feature is disabled"
    exit 0
fi

if ! grep -q "asymmetri Axcient" /proc/keys; then
    echo "WARNING: Secure Boot detected on this system. Either disable EFI Secure Boot "
    "or check with Axcient knowledgebase for instructions "
    "for enrolling a signing key for secure DKMS module support." >&2 \
    && exit 1
fi	

echo "Kernel Version: ${1}"
echo "Module Path: ${2}"

hash_algo=sha256
private_key=/root/axcient-driver.key
x509_cert=/root/axcient-driver.der

sign_util=/usr/src/linux-headers-${1}/scripts/sign-file 
if [ ! -e "${sign_util}" ]; then 
	sign_util=/usr/src/kernels/${1}/scripts/sign-file 
fi 

if [ ! -e "${sign_util}" ]; then 
	echo "WARNING: Cannot find the sign tool" 
	exit 0 
fi

if ! "${sign_util}" "${hash_algo}" "${private_key}" "${x509_cert}" "${2}" ; then
  echo "Error signing file ${2}." >&2
  exit 1
fi

echo "Signed newly-built module ${2} with MOK successfully." >&2
exit 0
