#!/bin/bash

set -e

DOCKER_IMAGE=${DOCKER_IMAGE:-bosh/blobstore_client}

docker login

echo "Building docker image..."
docker build -t $DOCKER_IMAGE .

echo "Pushing docker image to '$DOCKER_IMAGE'..."
docker push $DOCKER_IMAGE
