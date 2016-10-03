#!/bin/bash -l

set -e

source bosh-src/ci/tasks/utils.sh
check_param BOSH_AWS_ACCESS_KEY_ID
check_param BOSH_AWS_SECRET_ACCESS_KEY
check_param BOSH_AWS_SECRET_ACCESS_KEY
check_param BOSH_VAGRANT_PRIVATE_KEY
check_param OPERATING_SYSTEM_NAME
check_param OPERATING_SYSTEM_VERSION
check_param OS_IMAGE_S3_BUCKET_NAME
check_param OS_IMAGE_S3_KEY

set_up_vagrant_private_key

cd bosh-src
print_git_state

gem install bundler --version 1.11.2 --no-ri --no-rdoc
bundle install --local
bundle exec rake --trace ci:publish_os_image_in_vm[$OPERATING_SYSTEM_NAME,$OPERATING_SYSTEM_VERSION,remote,$OS_IMAGE_S3_BUCKET_NAME,$OS_IMAGE_S3_KEY]
