#!/bin/bash

set -e
set -x

INSTALL_PREFIX=/usr/lib/jvm
DOWNLOAD_URL=http://cdn.azulsystems.com/zulu/2014-10-8.4-bin/zulu1.8.0_25-8.4.0.1-x86lx64.zip
DOWNLOAD_ARGS="-O /tmp/zulu1.8.0_25-8.4.0.1-x86lx64.zip --continue --header=\"Referer: http://www.azulsystems.com/products/zulu/downloads\""

echo "Downloading Java..."
wget $DOWNLOAD_ARGS $DOWNLOAD_URL

echo "Extracting Java..."
mkdir -p $INSTALL_PREFIX
unzip zulu*.zip -d $INSTALL_PREFIX
