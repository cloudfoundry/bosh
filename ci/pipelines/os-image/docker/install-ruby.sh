#!/bin/bash

set -ex

RUBY_ROOT=/usr/local/ruby
RUBY_ARCHIVE_FILE=ruby-2.1.7.tar.gz
RUBY_ARCHIVE_URL=http://cache.ruby-lang.org/pub/ruby/2.1/${RUBY_ARCHIVE_FILE}
RUBY_NAME=$(basename -s .tar.gz $RUBY_ARCHIVE_URL)
RUBY_ARCHIVE_SHA=e2e195a4a58133e3ad33b955c829bb536fa3c075

echo "Downloading ruby..."
cd /tmp
wget -q ${RUBY_ARCHIVE_URL}
echo "${RUBY_ARCHIVE_SHA} ${RUBY_ARCHIVE_FILE}" > sha1sum.txt
sha1sum -c sha1sum.txt
rm sha1sum.txt
tar xf $RUBY_ARCHIVE_FILE

echo "Installing ruby..."
mkdir -p $(dirname $RUBY_ROOT)
cd $RUBY_NAME
./configure --prefix=$(dirname $RUBY_ROOT) --disable-install-doc --with-openssl-dir=/usr/include/openssl
make
make install
ln -s /usr/local/$RUBY_NAME $RUBY_ROOT

export PATH=$RUBY_ROOT/bin:$PATH

cd /tmp
rm $RUBY_ARCHIVE_FILE
