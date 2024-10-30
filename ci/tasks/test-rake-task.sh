#!/usr/bin/env bash
set -eu -o pipefail

source bosh-src/ci/tasks/utils.sh

start_db "${DB}"

pushd bosh-src/src
  print_git_state
  print_ruby_info

  gem install -f bundler
  bundle install --local

  bundle exec rake --trace "${RAKE_TASK}"
popd
