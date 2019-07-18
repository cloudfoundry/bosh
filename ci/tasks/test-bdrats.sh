#!/bin/bash

set -euo 'pipefail'

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
src_dir="${script_dir}/../../.."

export BOSH_RELEASE_PATH="${PWD}/bosh-release/$(basename bosh-release/*.tgz)"

mkdir -p bbr-binary
export BBR_VERSION=1.2.2
curl -L -o bbr-binary/bbr https://s3.amazonaws.com/bosh-dependencies/bbr-$BBR_VERSION
export BBR_SHA256=829160a61a44629a2626b578668777074c7badd75a9b5dab536defdbdd84b17a
export BBR_BINARY_PATH="${PWD}/bbr-binary/bbr"
chmod +x "${BBR_BINARY_PATH}"

${src_dir}/bosh-src/ci/docker/main-bosh-docker/start-bosh.sh \
  -o bbr.yml \
  -o uaa.yml \
  -o credhub.yml \
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

export INTEGRATION_CONFIG_PATH=${PWD}/integration-config.json
export GOPATH="${PWD}/gopath"
export PATH="${PATH}:${GOPATH}/bin"

pushd gopath/src/github.com/cloudfoundry-incubator/bosh-disaster-recovery-acceptance-tests
  go install ./vendor/github.com/onsi/ginkgo/ginkgo

  ./scripts/_run_acceptance_tests.sh
popd
