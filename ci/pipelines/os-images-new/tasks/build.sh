#!/bin/bash

set -eu

cd bosh-src
source ci/tasks/utils.sh
check_param BOSH_AWS_ACCESS_KEY_ID
check_param BOSH_AWS_SECRET_ACCESS_KEY
check_param OPERATING_SYSTEM_NAME
check_param OPERATING_SYSTEM_VERSION
check_param OS_IMAGE_S3_BUCKET_NAME
check_param OS_IMAGE_S3_KEY

sudo chown -R ubuntu .
sudo --preserve-env --set-home --user ubuntu -- /bin/bash --login -i <<SUDO
    bundle install --local
    bundle exec rake stemcell:build_os_image[$OPERATING_SYSTEM_NAME,$OPERATING_SYSTEM_VERSION,/tmp/bosh-$OPERATING_SYSTEM_NAME-$OPERATING_SYSTEM_VERSION-os-image.tgz]
    bundle exec rake stemcell:upload_os_image[/tmp/bosh-$OPERATING_SYSTEM_NAME-$OPERATING_SYSTEM_VERSION-os-image.tgz,$OS_IMAGE_S3_BUCKET_NAME,$OS_IMAGE_S3_KEY]
SUDO
