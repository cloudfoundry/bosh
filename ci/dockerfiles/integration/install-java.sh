#!/bin/bash
set -e
set -x

PACKAGE_NAME="zulu8.70.0.23-ca-jdk8.0.372-linux_x64.tar.gz"
PACKAGE_MD5="751deaa644a70fe7daa3d26bd3eb8e86"
PACKAGE_TMP="/tmp/${PACKAGE_NAME}"
PACKAGE_URL="http://cdn.azul.com/zulu/bin/${PACKAGE_NAME}"
INSTALL_PREFIX="/usr/lib/jvm"

echo "Downloading Java..."
wget -O $PACKAGE_TMP --continue $PACKAGE_URL

echo "Validating download"
# For checksum, you need two spaces between hash and file name or else it will fail with wrong format
echo "${PACKAGE_MD5}  ${PACKAGE_TMP}" | md5sum -c -

echo "Extracting Java..."
mkdir -p $INSTALL_PREFIX
tar xf $PACKAGE_TMP -C $INSTALL_PREFIX
mv $INSTALL_PREFIX/*/* $INSTALL_PREFIX
rm $PACKAGE_TMP
