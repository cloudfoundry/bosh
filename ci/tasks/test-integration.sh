#!/usr/bin/env bash
set -euo pipefail
set -x

BOSH_REPO='bosh'

source "${BOSH_REPO}/ci/tasks/utils.sh"

start_db "${DB}"

install bosh-cli/*bosh-cli-*-linux-amd64 "/usr/local/bin/bosh"

pushd "${BOSH_REPO}/src"
  print_git_state
  print_ruby_info

  gem install -f bundler
  bundle install --local

  bundle exec rake --trace spec:integration
popd
