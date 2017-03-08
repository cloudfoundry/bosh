#!/bin/bash

set -e
set -x

PACKAGE_NAME="zulu1.8.0_25-8.4.0.1-x86lx64"
PACKAGE_TMP="/tmp/$PACKAGE_NAME.zip"
PACKAGE_URL="http://cdn.azulsystems.com/zulu/2014-10-8.4-bin/$PACKAGE_NAME.zip"
REFERRER_URL="http://www.azulsystems.com/products/zulu/downloads"
INSTALL_PREFIX="/usr/lib/jvm"

echo "Downloading Java..."
wget -O $PACKAGE_TMP --continue --header="Referer: $REFERRER_URL" $PACKAGE_URL


echo "Extracting Java..."
mkdir -p $INSTALL_PREFIX
unzip $PACKAGE_TMP -d $INSTALL_PREFIX
rm $PACKAGE_TMP
