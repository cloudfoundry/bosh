#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh
check_param COMMAND
check_param RUBY_VERSION

cd bosh-src
print_git_state

if [ "$DB" != "" ] ; then
  start_db $DB
fi

source /etc/profile.d/chruby.sh
chruby $RUBY_VERSION
bundle install --local
bundle exec "$COMMAND"
