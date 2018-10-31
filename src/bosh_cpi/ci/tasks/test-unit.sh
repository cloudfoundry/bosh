#!/usr/bin/env bash

set -e

print_git_state() {
  if [ -d ".git" ] ; then
    echo "--> last commit..."
    TERM=xterm-256color git --no-pager log -1
    echo "---"
    echo "--> local changes (e.g., from 'fly execute')..."
    TERM=xterm-256color git --no-pager status --verbose
    echo "---"
  fi
}

: ${RUBY_VERSION:="2.3.1"}

source /etc/profile.d/chruby.sh
chruby $RUBY_VERSION

pushd bosh-cpi-ruby-gem
  print_git_state

  export PATH=/usr/local/ruby/bin:$PATH
  bundle install --local
  bundle exec rspec spec
popd
