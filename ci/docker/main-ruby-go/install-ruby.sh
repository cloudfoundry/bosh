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
    ruby-install --cleanup --sha256 "$sha" ruby "$version"

    source /etc/profile.d/chruby.sh

    chruby "ruby-$version"
    ruby -v
    gem update --system

}

install_ruby 2.3.6 07aa3ed3bffbfb97b6fc5296a86621e6bb5349c6f8e549bd0db7f61e3e210fd0
install_ruby 2.3.7 18b12fafaf37d5f6c7139c1b445355aec76baa625a40300598a6c8597fc04d8e
install_ruby 2.4.2 08e72d0cbe870ed1317493600fbbad5995ea3af2d0166585e7ecc85d04cc50dc
install_ruby 2.4.4 45a8de577471b90dc4838c5ef26aeb253a56002896189055a44dc680644243f1
install_ruby 2.4.5 276c8e73e51e4ba6a0fe81fb92669734e741ccea86f01c45e99f2c7ef7bcd1e3
