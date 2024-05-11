#!/bin/bash
set -eux

cp bosh-deployment/uaa.yml bosh-src-dockerfiles/ci/dockerfiles/integration/

cp -rp bosh-src-dockerfiles/ci/dockerfiles/integration/* docker-build-context
