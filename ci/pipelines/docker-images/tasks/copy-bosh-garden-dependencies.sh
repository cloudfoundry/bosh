#!/bin/bash

cp bosh-cli/*bosh* bosh-src/ci/docker/main-bosh-garden/bosh

mkdir bosh-src/ci/docker/main-bosh-garden/bosh-deployment
cp -R bosh-deployment/* bosh-src/ci/docker/main-bosh-garden/bosh-deployment

cp -R bosh-src/* bosh-src-with-garden-dependencies
