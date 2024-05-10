#!/bin/bash

set -eux

cp -rp bosh-src-dockerfiles/integration/* docker-build-context

mkdir docker-build-context/bosh-deployment
cp -R bosh-deployment/* docker-build-context/bosh-deployment
