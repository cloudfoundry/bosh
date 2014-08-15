#!/bin/bash

set -e
set -x

if [ "$RUBY_VERSION" == "" ]; then
  echo "RUBY_VERSION environment variable is required!"
  exit 1
fi
echo "Ruby Version: $RUBY_VERSION"

source /usr/local/etc/profile.d/chruby.sh

chruby $RUBY_VERSION

bundle install --local --without development

echo "DB: ${DB:?'<default>'}"
echo "Installing Go & Running integration tests..."
bundle exec rake --trace go spec:integration
