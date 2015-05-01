#!/usr/bin/env bash

set -e -x

export BOSH_CLI_SILENCE_SLOW_LOAD_WARNING=true

env | sort

source /etc/profile.d/chruby.sh
chruby $RUBY_VERSION
cd bosh-src

#git config --global user.email "cf-bosh-eng+bosh-ci@pivotal.io"
#git config --global user.name "bosh-ci"

echo "--- Starting bundle install in `pwd` @ `date` ---"
if [ -f .bundle/config ]; then
  echo ".bundle/config:"
  cat .bundle/config
fi

bundle install

if [ $# -ne 0 ]; then
  echo "--- Starting rake task @ `date` ---"
  bundle exec rake "$@"
fi
