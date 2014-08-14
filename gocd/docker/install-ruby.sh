#!/bin/bash

RUBY_INSTALL_URL=https://github.com/postmodern/ruby-install/archive/v0.4.3.tar.gz
RUBY_VERSIONS=( "1.9.3" "2.1.2" )

# chruby-0.3.8 setup script tries to install ruby-install and ruby 2.0.0, which fails
# wget -O chruby.tar.gz https://github.com/postmodern/chruby/archive/v0.3.8.tar.gz
# tar -xzvf chruby.tar.gz
# cd chruby/
# scripts/setup.sh
# cd ..
# rm -rf chruby/
# rm chruby.tar.gz

echo "Installing chruby..."
# TODO: use a release tarball instead once scripts/setup.sh doesn't install ruby any more
git clone https://github.com/postmodern/chruby.git
cd chruby/
git checkout dadcdba85e50fd2b62930d6bb7835972873f879b
scripts/setup.sh
cd ..
rm -rf chruby/

source /usr/local/etc/profile.d/chruby.sh

echo "Installing ruby-install..."
wget -O ruby-install.tar.gz $RUBY_INSTALL_URL
tar -xzvf ruby-install.tar.gz
cd ruby-install/
make install
cd ..
rm -rf ruby-install/
rm ruby-install.tar.gz

for version in "${RUBY_VERSIONS[@]}"; do
  echo "Installing ruby $version..."
  ruby-install ruby $version
  chruby "ruby-$version"
  gem install bundler
done
