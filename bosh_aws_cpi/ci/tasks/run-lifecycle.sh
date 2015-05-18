#!/usr/bin/env bash

set -e -x

export BOSH_CLI_SILENCE_SLOW_LOAD_WARNING=true

set +x
source deployments-bosh/concourse/$cpi_release_name/lifecycle-exports.sh
set -x

source /etc/profile.d/chruby.sh
chruby 2.1.6

cd bosh-src/$cpi_directory

bundle install

bundle exec rake spec:lifecycle
