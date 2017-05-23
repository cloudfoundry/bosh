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

mkdir -p bbr-binary
export BBR_VERSION=0.1.0-rc.251
curl -L -o bbr-binary/bbr https://s3.amazonaws.com/bosh-dependencies/bbr-$BBR_VERSION

export BBR_SHA256=0ef85538410ed8e756014d996de332376c1f584cd84f7cd744f34146b60966d7
export BBR_BINARY_PATH="${PWD}/bbr-binary/bbr"

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
