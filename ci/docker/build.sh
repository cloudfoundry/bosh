#!/bin/bash

set -e

if [ "" == "${1:-}" ] ; then
  echo "ERROR: include an image name as the first argument" 2>&1
  exit 1
fi

IMAGE_NAME="$1"
DOCKER_IMAGE=${DOCKER_IMAGE:-bosh/$IMAGE_NAME}

cd "$IMAGE_NAME"
docker build -t $DOCKER_IMAGE .
