#!/bin/bash

cp -rp bosh-src/ci/docker/main-bosh-${container_engine}/* docker-build-context

cp bosh-cli/*bosh* docker-build-context/bosh

mkdir docker-build-context/bosh-deployment
cp -R bosh-deployment/* docker-build-context/bosh-deployment
