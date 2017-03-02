#!/bin/bash

cp bosh-cli/*bosh* bosh-src/ci/docker/main-bosh-docker/bosh

mkdir bosh-src/ci/docker/main-bosh-docker/bosh-deployment
cp -R bosh-deployment/* bosh-src/ci/docker/main-bosh-docker/bosh-deployment

cp -R bosh-src/* bosh-src-with-docker-dependencies
