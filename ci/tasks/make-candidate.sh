#!/usr/bin/env bash

set -e

export CANDIDATE_BUILD_NUMBER=$(cat candidate-version/version)
export CANDIDATE_BUILD_GEM_NUMBER=$(cat candidate-gem-version/version || cat candidate-version/version)

source /etc/profile.d/chruby.sh
chruby 2.1.2

cd bosh-src
gem install bundler -v 1.15.3
bundle install
bundle exec rake release:create_dev_release

cd release
bundle exec bosh create release --force  --with-tarball --timestamp-version

mv dev_releases/bosh/*.tgz ../../release/
