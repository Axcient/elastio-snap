#!/bin/bash
#----------------------------------------------------------------------
#This script will be copied to docker image and launched as entry point
#----------------------------------------------------------------------
cd /build_dir

if [ -f /etc/redhat-release  ]; then
    sudo make rpm RELEASE_NUMBER=$1
    cp pkgbuild/RPMS/noarch/*.rpm pkgbuild/RPMS/x86_64/*.rpm /build-results
else
    sudo make deb RELEASE_NUMBER=$1
    cp pkgbuild/DEBS/all/*.deb pkgbuild/DEBS/amd64/*.deb /build-results
fi

sudo chown user:user -R /build-results
