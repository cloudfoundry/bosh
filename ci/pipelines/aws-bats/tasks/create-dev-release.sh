#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.1.2

out_dir=$PWD/bosh-dev-release
mkdir -p $out_dir

cd bosh-src
bundle install

echo "Creating dev-release"
bundle exec rake release:create_dev_release

cd release/
bundle exec bosh create release --with-tarball --force
mv dev_releases/bosh/bosh*.tgz ../../bosh-dev-release/
