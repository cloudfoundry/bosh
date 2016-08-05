#!/bin/bash

set -ex

# Pushing to Docker Hub requires login
DOCKER_IMAGE=${DOCKER_IMAGE:-bosh/vagrant-os-image-builder:257-x}

# To push to the Pivotal GoCD Docker Registry (behind firewall):
# DOCKER_IMAGE=docker.gocd.cf-app.com:5000/bosh-init-container

cd $(dirname $0)

echo "Downloading latest image to prime build cache..."
# failure to pull should not stop the build
set +e
docker pull $DOCKER_IMAGE
set -e

echo "Building docker image..."
docker build -t $DOCKER_IMAGE .

echo "Pushing docker image..."
docker push $DOCKER_IMAGE
