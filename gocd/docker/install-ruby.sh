#!/bin/bash

set -e
set -x

RUBY_INSTALL_URL=https://github.com/postmodern/ruby-install/archive/v0.4.3.tar.gz
RUBY_VERSIONS=( "1.9.3" "2.1.2" )

# chruby-0.3.8 setup script tries to install ruby-install and ruby 2.0.0, which fails
# wget -O chruby-0.3.8.tar.gz https://github.com/postmodern/chruby/archive/v0.3.8.tar.gz
# tar -xzvf chruby-0.3.8.tar.gz
# cd chruby-0.3.8/
# scripts/setup.sh
# cd ..
# rm -rf chruby-0.3.8/
# rm chruby-0.3.8.tar.gz

echo "Installing chruby..."
# TODO: use a release tarball instead once scripts/setup.sh doesn't install ruby any more
git clone https://github.com/postmodern/chruby.git
cd chruby/
git checkout dadcdba85e50fd2b62930d6bb7835972873f879b
scripts/setup.sh
cd ..
rm -rf chruby/

echo "Installing ruby-install..."
wget -O ruby-install-0.4.3.tar.gz $RUBY_INSTALL_URL
tar -xzvf ruby-install-0.4.3.tar.gz
cd ruby-install-0.4.3/
make install
cd ..
rm -rf ruby-install-0.4.3/
rm ruby-install-0.4.3.tar.gz

for version in "${RUBY_VERSIONS[@]}"; do
  echo "Installing ruby $version..."
  ruby-install ruby $version
done

source /etc/profile.d/chruby.sh

for version in "${RUBY_VERSIONS[@]}"; do
  echo "Switching to ruby $version..."
  chruby "ruby-$version"
  ruby -v
  echo "Installing bundler..."
  gem install bundler
done
