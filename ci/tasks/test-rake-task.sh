#!/usr/bin/env bash
set -eu -o pipefail

source bosh-ci/ci/tasks/utils.sh

if [ -d bosh-cli ] ; then
  install bosh-cli/*bosh-cli-*-linux-amd64 "/usr/local/bin/bosh"
fi

start_db "${DB}"

pushd bosh/src
  print_git_state
  print_ruby_info

  gem install -f bundler
  bundle install --local

  bundle exec rake --trace "${RAKE_TASK}"
popd
