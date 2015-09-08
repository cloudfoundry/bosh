#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh
check_param CLI_RUBY_VERSION
check_param DB

cd bosh-src
print_git_state

start_db $DB

# NOTE: We start the sandbox with the Ruby version specified in the BOSH
# release. The integration runner switches the CLI based upon the RUBY_VERSION
# environment variable.
BOSH_RUBY=$(
  grep -E "ruby-.*.tar.gz" release/packages/ruby/spec |\
  sed -r "s/^.*ruby-(.*).tar.gz/\1/"
)

source /etc/profile.d/chruby.sh

if [ "$CLI_RUBY_VERSION" != "$BOSH_RUBY" ] ; then
  # Make sure rubygems are installed for the CLI.
  chruby $CLI_RUBY_VERSION
  bundle install --local
fi

export BOSH_CLI_SILENCE_SLOW_LOAD_WARNING=true

chruby $BOSH_RUBY
bundle install --local
bundle exec rake --trace spec:integration
