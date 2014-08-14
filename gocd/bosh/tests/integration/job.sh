#!/bin/bash

if [ "$RUBY_VERSION" == "" ]; then
  echo "RUBY_VERSION environment variable is required!"
  exit 1
fi
echo "Ruby Version: $RUBY_VERSION"
chruby $RUBY_VERSION

echo "DB: ${DB:?'<default>'}"
echo "Installing Go & Running integration tests..."
bundle exec rake --trace go spec:integration
