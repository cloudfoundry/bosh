#!/usr/bin/env bash

DOCKER_IMAGE=${DOCKER_IMAGE:-bosh/main-no-redis}

exec docker run --privileged -v /opt/bosh:/opt/bosh --workdir /opt/bosh -t -i $DOCKER_IMAGE
