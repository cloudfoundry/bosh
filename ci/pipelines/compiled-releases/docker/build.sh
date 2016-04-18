#!/bin/bash

set -e

DOCKER_IMAGE=${DOCKER_IMAGE:-bosh/compiled-release}

docker build -t $DOCKER_IMAGE .
