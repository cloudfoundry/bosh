#!/bin/bash

set -e

DOCKER_IMAGE=${DOCKER_IMAGE:-bosh/main-ruby-go}

echo "Building docker image..."
docker build -t $DOCKER_IMAGE .
