#!/usr/bin/env bash

DOCKER_IMAGE=${DOCKER_IMAGE:-bosh/compiled-release}

docker login
docker push $DOCKER_IMAGE
