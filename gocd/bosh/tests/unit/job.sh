#!/bin/bash

if [ "$RUBY_VERSION" == "" ]; then
  echo "RUBY_VERSION environment variable is required!"
  exit 1
fi
echo "Ruby Version: $RUBY_VERSION"

source /usr/local/etc/profile.d/chruby.sh

chruby $RUBY_VERSION

bundle install --local --without development

echo "Installing Go & Running unit tests..."
bundle exec rake --trace go spec:unit
#COVERAGE=true bundle exec rake --trace go spec:unit ci:publish_coverage_report
