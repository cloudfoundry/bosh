#!/bin/bash

set -e
set -x

# builds and pushes a new 'bosh-container' to the Pivotal GoCD Docker Registry
VM_NAME=bosh-docker-builder

cd gocd/docker

[ -e .vagrant/machines/$VM_NAME/virtualbox/id ] && vagrant destroy $VM_NAME --force
vagrant up --provider virtualbox
[ -e .vagrant/machines/$VM_NAME/virtualbox/id ] && cat .vagrant/machines/$VM_NAME/virtualbox/id
[ -e .vagrant/machines/$VM_NAME/virtualbox/id ] && vagrant destroy $VM_NAME --force
