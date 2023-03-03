#!/bin/bash

set -eux

cp -rp bosh-src/ci/dockerfiles/warden-cpi/* docker-build-context

mkdir docker-build-context/bosh-deployment
cp -R bosh-deployment/* docker-build-context/bosh-deployment
