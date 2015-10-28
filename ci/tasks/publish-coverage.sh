#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh

check_param CODECLIMATE_REPO_TOKEN
check_param RUBY_VERSION

source /etc/profile.d/chruby.sh
chruby $RUBY_VERSION

cd bosh-src

print_git_state

bundle install --local

COVERAGE=true bundle exec rake go spec:unit ci:publish_coverage_report
