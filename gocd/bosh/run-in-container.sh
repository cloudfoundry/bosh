#!/bin/bash

set -e
set -x

if [ "$1" == "" ]; then
  echo "At least one argument required. ex: run-in-container.sh /path/to/cmd arg1 arg2"
  exit 1
fi

IMAGE_TAG=bosh-container
DOCKER_REGISTRY=docker.gocd.cf-app.com:5000

docker pull $DOCKER_REGISTRY/$IMAGE_TAG

docker run \
  -a stderr \
  -v $(pwd):/opt/bosh \
  -e RUBY_VERSION \
  -e DB \
  -e CODECLIMATE_REPO_TOKEN \
  $DOCKER_REGISTRY/$IMAGE_TAG \
  sudo chown ubuntu:ubuntu /opt/bosh && $@
