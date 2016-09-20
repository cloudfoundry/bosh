#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.1.2

cd bosh-src
bundle install
bundle exec rake release:create_dev_release

cd release
bundle exec bosh create release --force  --with-tarball --timestamp-version

mv dev_releases/bosh/*.tgz ../../release/
