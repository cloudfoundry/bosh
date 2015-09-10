#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh
check_param CLI_RUBY_VERSION
check_param DB
check_param SPEC_PATH

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

echo
echo "Running BOSH integration specs with..."
echo "  - Ruby $CLI_RUBY_VERSION for the CLI"
echo "  - Ruby $BOSH_RUBY for the Sandbox/Director"

source /etc/profile.d/chruby.sh

if [ "$CLI_RUBY_VERSION" != "$BOSH_RUBY" ] ; then
  # Make sure rubygems are installed for the CLI.
  echo
  echo "Installing gems for $CLI_RUBY_VERSION..."
  echo
  chruby $CLI_RUBY_VERSION
  bundle install --local
fi

echo
echo "Installing gems for $BOSH_RUBY..."
echo
chruby $BOSH_RUBY
bundle install --local

export BOSH_CLI_SILENCE_SLOW_LOAD_WARNING=true
bundle exec rake --trace spec:integration
