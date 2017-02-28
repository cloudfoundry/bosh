#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh

source /etc/profile.d/chruby.sh
chruby 2.1.2

pushd bosh-src
  bosh sync blobs
  chmod +x ./blobs/davcli/davcli-*-amd64

  pushd blobs
    BOSH_INSTALL_TARGET=$PWD/../src/tmp/integration-nginx bash ../packages/nginx/packaging
  popd

  pushd src
    bundle install

    pushd bosh-director
      bundle exec rspec spec/functional/dav_spec.rb --tag davcli_integration
    popd
  popd
popd

