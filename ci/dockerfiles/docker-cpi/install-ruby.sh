#!/bin/bash

set -e
set -x

RUBY_INSTALL_VER="0.8.1"
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

install_ruby 3.0.1 d06bccd382d03724b69f674bc46cd6957ba08ed07522694ce44b9e8ffc9c48e2
