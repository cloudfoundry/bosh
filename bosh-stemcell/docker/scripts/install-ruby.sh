#!/bin/bash

set -ex

CHRUBY_VER="0.3.9"
CHRUBY_SHA1=64365226210f82b58092ed01a3fb57d379b99c80
CHRUBY_URL=https://github.com/postmodern/chruby/archive/v${CHRUBY_VER}.tar.gz

RUBY_INSTALL_VER="0.5.0"
RUBY_INSTALL_SHA1=d8061e46fe2ea40f867e219cdd7d28fea24f47ca
RUBY_INSTALL_URL=https://github.com/postmodern/ruby-install/archive/v${RUBY_INSTALL_VER}.tar.gz

RUBY_VER="2.1.7"
RUBY_VER_SHA256=b02c1a5ecd718e3f6b316384d4ed6572f862a46063f5ae23d0340b0a245859b6

echo "Installing chruby v${CHRUBY_VER}..."
wget -O chruby-${CHRUBY_VER}.tar.gz https://github.com/postmodern/chruby/archive/v${CHRUBY_VER}.tar.gz

echo "${CHRUBY_SHA1} chruby-${CHRUBY_VER}.tar.gz" | sha1sum -c -

tar -xzvf chruby-${CHRUBY_VER}.tar.gz
cd chruby-${CHRUBY_VER}/
scripts/setup.sh
cd ..
rm -rf chruby-${CHRUBY_VER}/
rm chruby-${CHRUBY_VER}.tar.gz

echo "Installing ruby-install v${RUBY_INSTALL_VER}..."
wget -O ruby-install-${RUBY_INSTALL_VER}.tar.gz $RUBY_INSTALL_URL

echo  "${RUBY_INSTALL_SHA1} ruby-install-${RUBY_INSTALL_VER}.tar.gz" | sha1sum -c -

tar -xzvf ruby-install-${RUBY_INSTALL_VER}.tar.gz
cd ruby-install-${RUBY_INSTALL_VER}/
make install
cd ..
rm -rf ruby-install-${RUBY_INSTALL_VER}/
rm ruby-install-${RUBY_INSTALL_VER}.tar.gz

ruby-install --sha256 ${RUBY_VER_SHA256} ruby ${RUBY_VER}

echo 'source /etc/profile.d/chruby.sh' >> ~ubuntu/.bashrc
echo "chruby ruby-$RUBY_VER" >> ~ubuntu/.bashrc

source /etc/profile.d/chruby.sh
echo "Switching to ruby $RUBY_VER..."
chruby "ruby-$RUBY_VER"
ruby -v
echo "Installing bundler..."
gem install bundler
