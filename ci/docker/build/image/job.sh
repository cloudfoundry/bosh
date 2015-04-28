#!/bin/bash

set -e
set -x

# Pushing to Docker Hub requires login
#DOCKER_IMAGE=${DOCKER_IMAGE:-bosh/integration}

# To push to the Pivotal GoCD Docker Registry (behind firewall):
DOCKER_IMAGE=docker.gocd.cf-app.com:5000/bosh-container

SCRIPT_DIR=$(cd ./$(dirname $0) && pwd)
BOSH_DOCKER_DIR=$(cd $SCRIPT_DIR/../.. && pwd)
echo "BOSH_DOCKER_DIR: $BOSH_DOCKER_DIR"
cd $BOSH_DOCKER_DIR

echo "Downloading latest image to prime build cache..."
# failure to pull should not stop the build
set +e
docker pull $DOCKER_IMAGE
set -e

echo "Building docker image..."
docker build -t $DOCKER_IMAGE .

echo "Pushing docker image..."
docker push $DOCKER_IMAGE
