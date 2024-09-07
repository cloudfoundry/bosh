#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh
check_param RUBY_VERSION

start_db "${DB}"

pushd bosh-src/src
  print_git_state

  gem install -f bundler
  bundle install --local
  bundle exec rake --trace spec:unit
popd
