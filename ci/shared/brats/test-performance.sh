#!/usr/bin/env bash
set -eu -o pipefail

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${PWD}/bosh-debug.log}"
fi

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

source "${REPO_ROOT}/ci/dockerfiles/docker-cpi/start-bosh.sh"
source /tmp/local-bosh/director/env

export BOSH_DEPLOYMENT_PATH="/usr/local/bosh-deployment"

bosh int /tmp/local-bosh/director/creds.yml --path /jumpbox_ssh/private_key > /tmp/jumpbox_ssh_key.pem
chmod 400 /tmp/jumpbox_ssh_key.pem

BOSH_BINARY_PATH=$(which bosh)
export BOSH_BINARY_PATH
BOSH_DIRECTOR_TARBALL_PATH="$(find "${REPO_PARENT}/bosh-release" -maxdepth 1 -path '*.tgz')"
export BOSH_DIRECTOR_TARBALL_PATH
export BOSH_DIRECTOR_RELEASE_PATH="${REPO_PARENT}/bosh"
export CF_DEPLOYMENT_RELEASE_PATH="${REPO_PARENT}/cf-deployment"
CANDIDATE_STEMCELL_TARBALL_PATH="$(find "${REPO_PARENT}/stemcell" -maxdepth 1 -path '*.tgz')"
export CANDIDATE_STEMCELL_TARBALL_PATH
export STEMCELL_OS=ubuntu-noble

DOCKER_CERTS="$(bosh int /tmp/local-bosh/director/bosh-director.yml --path /instance_groups/0/properties/docker_cpi/docker/tls)"
export DOCKER_CERTS
DOCKER_HOST="$(bosh int /tmp/local-bosh/director/bosh-director.yml --path /instance_groups/name=bosh/properties/docker_cpi/docker/host)"
export DOCKER_HOST

bosh -n update-cloud-config \
  "${BOSH_DEPLOYMENT_PATH}/docker/cloud-config.yml" \
  -o "${REPO_ROOT}/ci/dockerfiles/docker-cpi/outer-cloud-config-ops.yml" \
  -v network=director_network

bosh -n upload-stemcell "${CANDIDATE_STEMCELL_TARBALL_PATH}"
bosh upload-release /usr/local/releases/bpm.tgz
bosh upload-release "$(bosh int ${BOSH_DEPLOYMENT_PATH}/docker/cpi.yml --path /name=cpi/value/url)" \
  --sha1 "$(bosh int ${BOSH_DEPLOYMENT_PATH}/docker/cpi.yml --path /name=cpi/value/sha1)"
bosh upload-release "$(bosh int ${BOSH_DEPLOYMENT_PATH}/jumpbox-user.yml --path /release=os-conf/value/url)" \
  --sha1 "$(bosh int ${BOSH_DEPLOYMENT_PATH}/jumpbox-user.yml --path /release=os-conf/value/sha1)"

pushd "${REPO_ROOT}/src/brats/performance"
  go run github.com/onsi/ginkgo/v2/ginkgo \
    -r -v --race --timeout=24h \
    --randomize-suites --randomize-all \
    --focus="${FOCUS_SPEC:-}" \
    --nodes 1 \
    .
popd
