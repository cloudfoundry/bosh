#!/bin/bash

set -e
set -x

IMAGE_TAG=bosh-container
DOCKER_REGISTRY=docker.gocd.cf-app.com:5000

SCRIPT_DIR=$(cd ./$(dirname $0) && pwd)
BOSH_DOCKER_DIR=$(cd $SCRIPT_DIR/../.. && pwd)
echo "BOSH_DOCKER_DIR: $BOSH_DOCKER_DIR"
cd $BOSH_DOCKER_DIR

docker build -t $DOCKER_REGISTRY/$IMAGE_TAG
docker push $DOCKER_REGISTRY/$IMAGE_TAG
