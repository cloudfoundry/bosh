#!/usr/bin/env bash

set -eu

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
src_dir="${script_dir}/../../.."

export BOSH_DEPLOYMENT_PATH="/usr/local/bosh-deployment"

source "${src_dir}/bosh/ci/dockerfiles/docker-cpi/start-bosh.sh"
source /tmp/local-bosh/director/env

bosh int /tmp/local-bosh/director/creds.yml --path /jumpbox_ssh/private_key > /tmp/jumpbox_ssh_key.pem
chmod 400 /tmp/jumpbox_ssh_key.pem

export BOSH_DIRECTOR_IP="10.245.0.3"

export BOSH_BINARY_PATH=$(which bosh)
bosh_release_tgz=(${PWD}/bosh-release/*.tgz)
export BOSH_DIRECTOR_TARBALL_PATH=${bosh_release_tgz[0]}
export BOSH_DIRECTOR_RELEASE_PATH="$PWD/bosh"
export CF_DEPLOYMENT_RELEASE_PATH="$PWD/cf-deployment"
export CANDIDATE_STEMCELL_TARBALL_PATH="$(realpath "${src_dir}"/stemcell/*.tgz)"
export STEMCELL_OS=ubuntu-jammy

export DOCKER_CERTS="$(bosh int /tmp/local-bosh/director/bosh-director.yml --path /instance_groups/0/properties/docker_cpi/docker/tls)"
export DOCKER_HOST="$(bosh int /tmp/local-bosh/director/bosh-director.yml --path /instance_groups/name=bosh/properties/docker_cpi/docker/host)"

bosh -n update-cloud-config \
  "${BOSH_DEPLOYMENT_PATH}/docker/cloud-config.yml" \
  -o "${src_dir}/bosh-ci/ci/dockerfiles/docker-cpi/outer-cloud-config-ops.yml" \
  -v network=director_network

bosh -n upload-stemcell "${CANDIDATE_STEMCELL_TARBALL_PATH}"
bosh upload-release /usr/local/bpm.tgz
bosh upload-release "$(bosh int ${BOSH_DEPLOYMENT_PATH}/docker/cpi.yml --path /name=cpi/value/url)" \
  --sha1 "$(bosh int ${BOSH_DEPLOYMENT_PATH}/docker/cpi.yml --path /name=cpi/value/sha1)"
bosh upload-release "$(bosh int ${BOSH_DEPLOYMENT_PATH}/jumpbox-user.yml --path /release=os-conf/value/url)" \
  --sha1 "$(bosh int ${BOSH_DEPLOYMENT_PATH}/jumpbox-user.yml --path /release=os-conf/value/sha1)"

pushd "${src_dir}/bosh/src/brats" > /dev/null
  go run github.com/onsi/ginkgo/v2/ginkgo --timeout=24h -r --race --nodes 1 performance
popd > /dev/null
