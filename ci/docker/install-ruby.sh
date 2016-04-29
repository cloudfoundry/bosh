#!/bin/bash

set -e
set -x

CHRUBY_VER="0.3.9"
CHRUBY_URL=https://github.com/postmodern/chruby/archive/v${CHRUBY_VER}.tar.gz
RUBY_INSTALL_VER="0.5.0"
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
    ruby-install --sha256 "$sha" ruby "$version"

    source /etc/profile.d/chruby.sh

    chruby "ruby-$version"
    ruby -v
    gem update --system
    gem install bundler -v 1.11.2

}

install_ruby 1.9.3 ef588ed3ff53009b4c1833c83187ae252dd6c20db45e21a326cd4a16a102ef4c
install_ruby 2.1.7 b02c1a5ecd718e3f6b316384d4ed6572f862a46063f5ae23d0340b0a245859b6
install_ruby 2.3.1 4a7c5f52f205203ea0328ca8e1963a7a88cf1f7f0e246f857d595b209eac0a4d
