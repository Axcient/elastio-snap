#!/bin/sh

echo "INFORMATION: Running the Axcient Kernel Module certificate checker"

if ! $(mokutil --sb-state | grep -q enabled); then
    echo "INFORMATION: Detected a BIOS firmware or the Secure Boot feature is disabled"
    exit 0
fi

if ! $(modinfo elastio-snap | grep -q signer); then
    echo "WARNING: It seems that the kernel module is not signed"
    exit 0
fi

signer_name=$(modinfo elastio-snap | grep signer | xargs | sed s/"signer: "//)
if ! $(mokutil --list-enrolled | grep -q "${signer_name}"); then
    echo "WARNING: Secure Boot detected on this system. Either disable EFI Secure Boot " \
    "or check with Axcient knowledgebase for instructions " \
    "for enrolling a signing key for secure DKMS module support."
    exit 0
fi	

echo "INFORMATION: Everything is setup correctly"
exit 0
