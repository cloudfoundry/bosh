#!/bin/bash

set -e
set -x

CHRUBY_VER="0.3.9"
CHRUBY_URL=https://github.com/postmodern/chruby/archive/v${CHRUBY_VER}.tar.gz
RUBY_INSTALL_VER="0.8.3"
RUBY_INSTALL_URL=https://github.com/postmodern/ruby-install/archive/v${RUBY_INSTALL_VER}.tar.gz

echo "Installing chruby v${CHRUBY_VER}..."
wget -O chruby-${CHRUBY_VER}.tar.gz https://github.com/postmodern/chruby/archive/v${CHRUBY_VER}.tar.gz
tar -xzvf chruby-${CHRUBY_VER}.tar.gz
cd chruby-${CHRUBY_VER}/
scripts/setup.sh
cd ..
rm -rf chruby-${CHRUBY_VER}/
rm chruby-${CHRUBY_VER}.tar.gz

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
    ruby-install --cleanup --sha256 "$sha" ruby "$version"

    source /etc/profile.d/chruby.sh

    chruby "ruby-$version"
    ruby -v
    gem update --system

}

install_ruby 3.1.2 ca10d017f8a1b6d247556622c841fc56b90c03b1803f87198da1e4fd3ec3bf2a
