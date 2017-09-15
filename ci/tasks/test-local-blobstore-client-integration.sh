#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh

source /etc/profile.d/chruby.sh
chruby 2.1.2

pushd bosh-src
  bosh sync blobs

  pushd src
    bundle install

    pushd bosh-director
      bundle exec rspec spec/functional/local_spec.rb --tag local_blobstore_integration
    popd
  popd
popd

