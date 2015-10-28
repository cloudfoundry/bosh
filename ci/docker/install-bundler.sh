#!/bin/bash

set -e
set -x

RUBY_VERSIONS=( "1.9.3" "2.1.7" )

source /etc/profile.d/chruby.sh

for version in "${RUBY_VERSIONS[@]}"; do
  echo "Switching to ruby $version..."
  chruby "ruby-$version"
  ruby -v
  echo "Installing bundler..."
  gem install bundler
done
