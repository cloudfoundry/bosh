#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh
check_param RAKE_TASKS
check_param RUBY_VERSION

cd bosh-src
print_git_state

source /etc/profile.d/chruby.sh
chruby $RUBY_VERSION

export PATH=/usr/local/ruby/bin:/usr/local/go/bin:$PATH
export GOPATH=$(pwd)/go
bundle install --local
bundle exec rake --trace $RAKE_TASKS
