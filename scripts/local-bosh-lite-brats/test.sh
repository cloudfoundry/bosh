#!/usr/bin/env bash

set -eu

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
src_dir="${script_dir}/../../../"

export BOSH_DIRECTOR_IP="10.245.0.3"

export BOSH_RELEASE="${HOME}/workspace/bosh/src/spec/assets/dummy-release.tgz"
export BOSH_DIRECTOR_RELEASE_PATH=/tmp/bosh-release
export DNS_RELEASE_PATH=/tmp/bosh-dns-release/release.tgz
export CANDIDATE_STEMCELL_TARBALL_PATH=/tmp/candidate-warden-ubuntu-stemcell/bosh-stemcell-3586.16-warden-boshlite-ubuntu-trusty-go_agent.tgz
export BOSH_DNS_ADDON_OPS_FILE_PATH="${HOME}/workspace/bosh-deployment/misc/dns-addon.yml"

export BOSH_BINARY_PATH=$(which bosh)
export BBR_BINARY_PATH=$(which bbr)

export DOCKER_CERTS="$(bosh int "${HOME}/deployments/vbox/creds.yml" --path /docker_client_tls)"
export DOCKER_HOST="tcp://192.168.50.6:4243"

export OUTER_BOSH_ENV_PATH="${HOME}/workspace/bosh/.envrc"
export BOSH_DEPLOYMENT_PATH="${HOME}/workspace/bosh-deployment"

scripts/test-brats
