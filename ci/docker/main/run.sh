#!/usr/bin/env bash

DOCKER_IMAGE=${DOCKER_IMAGE:-bosh/main}

exec docker run --privileged -v /opt/bosh:/opt/bosh --workdir /opt/bosh -t -i $DOCKER_IMAGE
