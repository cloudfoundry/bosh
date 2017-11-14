#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh

check_param RUBY_VERSION

source /etc/profile.d/chruby.sh
chruby $RUBY_VERSION

pushd bosh-src
  bosh sync blobs

  pushd src
    bundle install

    pushd bosh-director
      bundle exec rspec spec/functional/local_spec.rb --tag local_blobstore_integration
    popd
  popd
popd

