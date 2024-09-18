#!/usr/bin/env bash

set -euo pipefail
set -x

source bosh-src/ci/tasks/utils.sh

check_param RUBY_VERSION
check_param DB

start_db "${DB}"

install ./bosh-cli/*bosh-cli-*-linux-amd64 /usr/local/bin/bosh

agent_path=bosh-src/src/go/src/github.com/cloudfoundry/
mkdir -p "${agent_path}"
cp -r bosh-agent "${agent_path}"

pushd bosh-src/src
  print_git_state

  gem install -f bundler
  bundle install --local
  
  bundle exec rake --trace spec:integration
popd
