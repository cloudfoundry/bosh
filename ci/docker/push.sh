#!/bin/bash

set -e

DOCKER_IMAGE=${DOCKER_IMAGE:-bosh/main}

docker login

echo "Pushing docker image..."
docker push $DOCKER_IMAGE
