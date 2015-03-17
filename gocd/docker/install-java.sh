#!/bin/bash

set -e
set -x

INSTALL_PREFIX=/usr/lib/jvm

echo "Downloading Java..."
wget -O /tmp/zulu1.8.0_25-8.4.0.1-x86lx64.zip --continue \
--header=\"Referer: http://www.azulsystems.com/products/zulu/downloads\" \
http://cdn.azulsystems.com/zulu/2014-10-8.4-bin/zulu1.8.0_25-8.4.0.1-x86lx64.zip

echo "Extracting Java..."
mkdir -p $INSTALL_PREFIX
unzip zulu*.zip -d $INSTALL_PREFIX
