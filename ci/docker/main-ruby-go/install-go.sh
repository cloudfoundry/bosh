#!/usr/bin/env bash

set -eux

GOPATH=/home/vagrant/go
GO_ARCHIVE_URL=https://storage.googleapis.com/golang/go1.10.1.linux-amd64.tar.gz
GO_ARCHIVE_SHA256=72d820dec546752e5a8303b33b009079c15c2390ce76d67cf514991646c6127b
GO_ARCHIVE=/tmp/$(basename $GO_ARCHIVE_URL)

echo "Downloading go..."
mkdir -p $(dirname $GOROOT)
wget -q $GO_ARCHIVE_URL -O $GO_ARCHIVE
echo "${GO_ARCHIVE_SHA256} ${GO_ARCHIVE}" | sha256sum -c -
tar xf $GO_ARCHIVE -C $(dirname $GOROOT)

rm -f $GO_ARCHIVE
