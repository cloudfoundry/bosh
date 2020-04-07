#!/usr/bin/env bash

set -eu

source bosh-src/ci/tasks/utils.sh

source start-bosh

export BOSH_DIRECTOR_IP="10.245.0.3"
export AGENT_PASSWORD=$(bosh int /tmp/local-bosh/director/creds.yml --path /blobstore_agent_password)

export DAVCLI_PATH=$(echo $PWD/davcli/davcli-*)
chmod +x $DAVCLI_PATH

pushd bosh-src/src/go
  export GOPATH=$(pwd)
  export PATH="${GOPATH}/bin":$PATH

  pushd src/github.com/cloudfoundry/bosh-blobstore-load-tests
    go install ./vendor/github.com/onsi/ginkgo/ginkgo
    ginkgo -r -race -randomizeSuites -randomizeAllSpecs .
  popd
popd
