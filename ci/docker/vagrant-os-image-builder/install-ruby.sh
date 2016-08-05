#!/bin/bash

set -ex

RUBY_ROOT=/usr/local/ruby
RUBY_ARCHIVE_URL=http://cache.ruby-lang.org/pub/ruby/2.1/ruby-2.1.6.tar.gz
RUBY_ARCHIVE=$(basename $RUBY_ARCHIVE_URL)
RUBY_NAME=$(basename -s .tar.gz $RUBY_ARCHIVE_URL)

echo "Downloading ruby..."
wget -q $RUBY_ARCHIVE_URL
tar xf $RUBY_ARCHIVE

echo "Installing ruby..."
mkdir -p $(dirname $RUBY_ROOT)
cd $RUBY_NAME
./configure --prefix=$(dirname $RUBY_ROOT) --disable-install-doc --with-openssl-dir=/usr/include/openssl
make
make install
ln -s /usr/local/$RUBY_NAME $RUBY_ROOT

export PATH=$RUBY_ROOT/bin:$PATH
