#!/usr/bin/env bash

set -eu

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
src_dir="${script_dir}/../../../"

"${src_dir}bosh-src/ci/docker/main-bosh-docker/start-bosh.sh"

source /tmp/local-bosh/director/env

bosh int /tmp/local-bosh/director/creds.yml --path /jumpbox_ssh/private_key > /tmp/jumpbox_ssh_key.pem
chmod 400 /tmp/jumpbox_ssh_key.pem

export BOSH_SSH_PRIVATE_KEY_PATH="/tmp/jumpbox_ssh_key.pem"
export BOSH_BINARY_PATH=$(which bosh)
export BOSH_RELEASE="${PWD}/bosh-src/src/spec/assets/dummy-release.tgz"
export BOSH_DIRECTOR_IP="10.245.0.3"

export BBR_VERSION=0.1.0-rc.237
export BBR_SHA256=033d58fd9b3efbd54412aaeccd95391c2c5306bb7c50aa29d2e19c28e3e7361b
export BBR_BINARY_PATH="${PWD}/bbr-binary/bbr-${BBR_VERSION}"

echo "${BBR_SHA256} ${BBR_BINARY_PATH}" | sha256sum -c -

chmod +x ${BBR_BINARY_PATH}

pushd bosh-src/src/go
  export GOPATH=$(pwd)
  export PATH="${GOPATH}/bin":$PATH

  pushd src/github.com/cloudfoundry/bosh-release-acceptance-tests
    go install ./vendor/github.com/onsi/ginkgo/ginkgo
    ginkgo -v -r -race -randomizeSuites -randomizeAllSpecs .
  popd
popd
