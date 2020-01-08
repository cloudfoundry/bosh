#!/bin/bash

set -e
set -x

RUBY_INSTALL_VER="0.7.0"
RUBY_INSTALL_URL=https://github.com/postmodern/ruby-install/archive/v${RUBY_INSTALL_VER}.tar.gz

echo "Installing ruby-install v${RUBY_INSTALL_VER}..."
wget -O ruby-install-${RUBY_INSTALL_VER}.tar.gz $RUBY_INSTALL_URL
tar -xzvf ruby-install-${RUBY_INSTALL_VER}.tar.gz
cd ruby-install-${RUBY_INSTALL_VER}/
make install
cd ..
rm -rf ruby-install-${RUBY_INSTALL_VER}/
rm ruby-install-${RUBY_INSTALL_VER}.tar.gz

install_ruby() {
    local version=$1
    local sha=$2

    echo "Installing ruby $version..."
    ruby-install --jobs=2 --cleanup --system --sha256 "$sha" ruby "$version" -- --disable-install-rdoc

    ruby -v
    gem update --system

}

install_ruby 2.6.5 97ddf1b922f83c1f5c50e75bf54e27bba768d75fea7cda903b886c6745e60f0a
