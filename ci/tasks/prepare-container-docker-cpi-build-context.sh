#!/bin/bash

cp -rp bosh-ci-dockerfiles/ci/dockerfiles/docker-cpi/* docker-build-context

cp bosh-cli/*bosh* docker-build-context/bosh

mkdir docker-build-context/bosh-deployment
cp -R bosh-deployment/* docker-build-context/bosh-deployment
