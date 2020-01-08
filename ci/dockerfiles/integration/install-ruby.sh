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

install_ruby 2.6.3 dd638bf42059182c1d04af0d5577131d4ce70b79105231c4cc0a60de77b14f2e
