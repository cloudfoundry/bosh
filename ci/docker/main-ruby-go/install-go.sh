#!/usr/bin/env bash

set -eux

GOPATH=/home/vagrant/go
GO_ARCHIVE_URL=https://storage.googleapis.com/golang/go1.8.3.linux-amd64.tar.gz
GO_ARCHIVE_SHA256=1862f4c3d3907e59b04a757cfda0ea7aa9ef39274af99a784f5be843c80c6772
GO_ARCHIVE=/tmp/$(basename $GO_ARCHIVE_URL)

echo "Downloading go..."
mkdir -p $(dirname $GOROOT)
wget -q $GO_ARCHIVE_URL -O $GO_ARCHIVE
echo "${GO_ARCHIVE_SHA256} ${GO_ARCHIVE}" | sha256sum -c -
tar xf $GO_ARCHIVE -C $(dirname $GOROOT)

rm -f $GO_ARCHIVE
