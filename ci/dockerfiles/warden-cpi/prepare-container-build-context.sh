#!/bin/bash

set -eux

cp -rp bosh-src/ci/dockerfiles/warden-cpi/* docker-build-context

cp bosh-cli-github-release/bosh-cli-*-linux-amd64 docker-build-context/bosh

mkdir docker-build-context/bosh-deployment
cp -R bosh-deployment/* docker-build-context/bosh-deployment
