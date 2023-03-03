#!/bin/bash

set -euo 'pipefail'

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
src_dir="${script_dir}/../../.."

export BOSH_RELEASE_PATH="${PWD}/bosh-release/$(basename bosh-release/*.tgz)"

mkdir -p bbr-binary
export BBR_BINARY_PATH="${PWD}/bbr-binary/bbr"
cp bbr-cli-binary/bbr-[0-9]*-linux-amd64 $BBR_BINARY_PATH
chmod +x "${BBR_BINARY_PATH}"

export OVERRIDDEN_BOSH_DEPLOYMENT="${src_dir}/bosh-deployment"
if [[ -e ${OVERRIDDEN_BOSH_DEPLOYMENT}/bosh.yml ]];then
  export BOSH_DEPLOYMENT_PATH=${OVERRIDDEN_BOSH_DEPLOYMENT}
fi

source ${src_dir}/bosh-src/ci/dockerfiles/docker-cpi/start-bosh.sh \
  -o bbr.yml \
  -o local-bosh-release-tarball.yml \
  -o hm/disable.yml \
  -v local_bosh_release=${BOSH_RELEASE_PATH}

source /tmp/local-bosh/director/env

STEMCELL_PATH="${PWD}/stemcell/$(basename stemcell/*.tgz)"
BOSH_SSH_KEY="$(bosh int /tmp/local-bosh/director/creds.yml --path /jumpbox_ssh/private_key --json | jq .Blocks[0])"
BOSH_HOST="$(bosh envs | grep ${BOSH_ENVIRONMENT} | cut -f1)"

cat > integration-config.json <<EOF
{
  "bosh_host": "${BOSH_HOST}",
  "bosh_ssh_username": "jumpbox",
  "bosh_ssh_private_key": ${BOSH_SSH_KEY},
  "bosh_client": "${BOSH_CLIENT}",
  "bosh_client_secret": "${BOSH_CLIENT_SECRET}",
  "bosh_ca_cert": "",
  "timeout_in_minutes": 30,
  "stemcell_src": "${STEMCELL_PATH}",
  "include_deployment_testcase": true,
  "include_truncate_db_blobstore_testcase": true
}
EOF

set -x # debugging info
export INTEGRATION_CONFIG_PATH=${PWD}/integration-config.json
export GOPATH="${PWD}/gopath"
export PATH="${PATH}:${GOPATH}/bin"

# Note: this must happen in the context of a `go.mod` file, otherwise `@{VERSION}` must be used
# => https://go.dev/doc/go-get-install-deprecation
export GINKGO_VERSION="v1.16.5"
go install "github.com/onsi/ginkgo/ginkgo@${GINKGO_VERSION}"


# Hotfix until PR is merged: https://github.com/cloudfoundry/bosh-disaster-recovery-acceptance-tests/pull/41
sed -i "s/^  os:.*/  os: $(cat stemcell/url  | cut -d- -f8-9)/g" $(find -name small-deployment.yml)

export GINKGO_TIMEOUT="24h0m0s"
pushd gopath/src/github.com/cloudfoundry-incubator/bosh-disaster-recovery-acceptance-tests
  ./scripts/_run_acceptance_tests.sh
popd
