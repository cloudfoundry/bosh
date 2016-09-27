#!/bin/bash

set -eu

TASK_DIR=$PWD

cd bosh-src

source ci/tasks/utils.sh
check_param OPERATING_SYSTEM_NAME
check_param OPERATING_SYSTEM_VERSION

OS_IMAGE_NAME=$OPERATING_SYSTEM_NAME-$OPERATING_SYSTEM_VERSION
OS_IMAGE=$TASK_DIR/os-image/$OS_IMAGE_NAME.tgz

sudo chown -R ubuntu .
sudo --preserve-env --set-home --user ubuntu -- /bin/bash --login -i <<SUDO
    bundle install --local
    bundle exec rake stemcell:build_os_image[$OPERATING_SYSTEM_NAME,$OPERATING_SYSTEM_VERSION,$OS_IMAGE]
SUDO
