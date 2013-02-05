#!/bin/bash
set -e

source .rvmrc
gem list | grep bundler || gem install bundler
bundle check || bundle install --without development

set +e
ruby integration_tests/aws/create_aws_resources.rb &&
    bundle exec rake spec:integration
TEST_EXIT_CODE=$?

ruby integration_tests/aws/cleanup_aws_resources.rb
CLEAN_UP_EXIT_CODE=$?

exit $(($TEST_EXIT_CODE || $CLEAN_UP_EXIT_CODE))
