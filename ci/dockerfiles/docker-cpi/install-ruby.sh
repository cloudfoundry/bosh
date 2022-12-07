#!/bin/bash

set -e
set -x

apt update && apt install jq -y

RUBY_INSTALL_VER="$(curl -s -H "X-GitHub-Api-Version: 2022-11-28" -H "Accept: application/vnd.github+json"  https://api.github.com/repos/postmodern/ruby-install/tags | jq '.[].name ' -r | grep '^v'| sed 's/^v//' | sort --version-sort | tail -1)"
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

    echo "Installing ruby $version..."
    ruby-install --jobs=2 --cleanup --system ruby "$version" -- --disable-install-rdoc

    ruby -v
    gem update --system
}

install_ruby 3.1
