#!/usr/bin/env bash

set -eux

GOPATH=/home/vagrant/go
GO_ARCHIVE_URL=https://storage.googleapis.com/golang/go1.6.1.linux-amd64.tar.gz
GO_ARCHIVE_SHA256=6d894da8b4ad3f7f6c295db0d73ccc3646bce630e1c43e662a0120681d47e988
GO_ARCHIVE=/tmp/$(basename $GO_ARCHIVE_URL)

echo "Downloading go..."
mkdir -p $(dirname $GOROOT)
wget -q $GO_ARCHIVE_URL -O $GO_ARCHIVE
echo "${GO_ARCHIVE_SHA256} ${GO_ARCHIVE}" | sha256sum -c -
tar xf $GO_ARCHIVE -C $(dirname $GOROOT)

rm -f $GO_ARCHIVE
