#!/usr/bin/env bash

set -e -x

export BOSH_CLI_SILENCE_SLOW_LOAD_WARNING=true

env | sort

source /etc/profile.d/chruby.sh
chruby $RUBY_VERSION
cd bosh-src

echo "--- Starting bundle install in `pwd` @ `date` ---"
if [ -f .bundle/config ]; then
  echo ".bundle/config:"
  cat .bundle/config
fi

bundle install
echo "--- Starting rake task @ `date` ---"
bundle exec rake "$@"
