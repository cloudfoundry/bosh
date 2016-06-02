#!/bin/bash

set -e

DOCKER_IMAGE=${DOCKER_IMAGE:-bosh/main}

docker login

echo "Building docker image..."
docker build -t $DOCKER_IMAGE .

echo "Pushing docker image..."
docker push $DOCKER_IMAGE
