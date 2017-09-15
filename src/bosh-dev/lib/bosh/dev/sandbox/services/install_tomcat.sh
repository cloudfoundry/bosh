#!/usr/bin/env bash

set -eux

INSTALL_DIR=$1
VERSIONED_FILENAME=$2
ARCHIVE_SHA=$3

ARCHIVE_URL=https://s3.amazonaws.com/bosh-dependencies/${VERSIONED_FILENAME}.tar.gz
ARCHIVE=/tmp/$(basename $ARCHIVE_URL)

wget -q -c $ARCHIVE_URL -O $ARCHIVE
echo "${ARCHIVE_SHA}  ${ARCHIVE}" | shasum -c -
tar xf $ARCHIVE -C $INSTALL_DIR
rm -f $ ARCHIVE
