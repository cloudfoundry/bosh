#!/bin/bash

if [ "$1" == "" ]; then
  echo "Argument required: <path/to/script.sh>"
  exit 1
fi

IMAGE_TAG=bosh-container
DOCKER_REGISTRY=docker.gocd.cf-app.com:5000

docker pull $DOCKER_REGISTRY/$IMAGE_TAG

docker run \
  -v $(pwd):/opt/bosh \
  -e RUBY_VERSION \
  -e DB \
  -e CODECLIMATE_REPO_TOKEN \
  $DOCKER_REGISTRY/$IMAGE_TAG \
  $1
