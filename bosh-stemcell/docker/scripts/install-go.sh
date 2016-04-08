#!/bin/bash

set -eux

GOPATH=/usr/local/go
GO_ARCHIVE_URL=https://storage.googleapis.com/golang/go1.5.1.linux-amd64.tar.gz
GO_ARCHIVE_SHA1=46eecd290d8803887dec718c691cc243f2175fe0
GO_ARCHIVE=/tmp/$(basename $GO_ARCHIVE_URL)

echo "Downloading go..."
mkdir -p $(dirname $GOROOT)
wget -q $GO_ARCHIVE_URL -O $GO_ARCHIVE

echo "${GO_ARCHIVE_SHA1} ${GO_ARCHIVE}" | sha1sum -c -

tar xf $GO_ARCHIVE -C $(dirname $GOROOT)

for GO_EXECUTABLE in $GOROOT/bin/*; do
  ln -s $GO_EXECUTABLE /usr/bin/
done

rm -f $GO_ARCHIVE
