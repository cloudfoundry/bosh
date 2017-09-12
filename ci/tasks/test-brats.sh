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
export BOSH_DIRECTOR_RELEASE_PATH="${PWD}/bosh-release/*.tgz"

if [[ -d ${DNS_RELEASE_FILE_PATH} ]]; then
  export DNS_RELEASE_PATH="${DNS_RELEASE_FILE_PATH}/release.tgz"
  pushd ${DNS_RELEASE_FILE_PATH}
    bosh create-release --tarball $DNS_RELEASE_PATH
  popd
else
  export DNS_RELEASE_PATH="${src_dir}${DNS_RELEASE_FILE_PATH}"
fi

export CANDIDATE_STEMCELL_TARBALL_PATH="$(realpath ${src_dir}candidate-warden-ubuntu-stemcell/*.tgz)"

mkdir -p bbr-binary
export BBR_VERSION=0.1.0-rc.254
curl -L -o bbr-binary/bbr https://s3.amazonaws.com/bosh-dependencies/bbr-$BBR_VERSION

export BBR_SHA256=9dd791b0c521d3138711a1c5a7f9dcb3b627066d9728fb54cf9de9c5337a5c6b
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
