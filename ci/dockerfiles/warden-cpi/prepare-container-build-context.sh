#!/bin/bash

set -eux

cp -rp bosh-ci-dockerfiles/ci/dockerfiles/warden-cpi/* docker-build-context

mkdir docker-build-context/bosh-deployment
cp -R bosh-deployment/* docker-build-context/bosh-deployment
