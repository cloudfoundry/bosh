#!/bin/bash

set -e
set -x

SCRIPT_DIR=$(cd ./$(dirname $0) && pwd)
BOSH_DOCKER_DIR=$(cd $SCRIPT_DIR/../.. && pwd)
echo "BOSH_DOCKER_DIR: $BOSH_DOCKER_DIR"
cd $BOSH_DOCKER_DIR

# builds and pushes a new 'bosh-container' to the Pivotal GoCD Docker Registry
VM_NAME=bosh-docker-builder

[ -e .vagrant/machines/$VM_NAME/virtualbox/id ] && vagrant destroy $VM_NAME --force
vagrant up --provider virtualbox
[ -e .vagrant/machines/$VM_NAME/virtualbox/id ] && cat .vagrant/machines/$VM_NAME/virtualbox/id
[ -e .vagrant/machines/$VM_NAME/virtualbox/id ] && vagrant destroy $VM_NAME --force
