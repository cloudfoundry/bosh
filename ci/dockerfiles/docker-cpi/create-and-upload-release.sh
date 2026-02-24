#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

BOSH_DEPLOYMENT_PATH="${BOSH_DEPLOYMENT_PATH:-/usr/local/bosh-deployment}"

pushd "${REPO_PARENT}/bosh"
  if [[ ! -e $(find . -maxdepth 1 -name "*.tgz") ]]; then
    bosh reset-release
    bosh create-release --force --tarball release.tgz
  fi

  bosh_release_path="$(realpath "$(find . -maxdepth 1 -name "*.tgz")")"
popd

bosh upload-release "${bosh_release_path}" --name=bosh

pushd "${REPO_ROOT}/src/brats/assets/linked-templates-release"
  if [[ ! -e $(find . -maxdepth 1 -name "*.tgz") ]]; then
    bosh reset-release
    bosh create-release --force --tarball release.tgz
  fi
popd

pushd "${BOSH_DEPLOYMENT_PATH}"
  node_number="${1}"

  export BOSH_DIRECTOR_IP="10.245.0.$((10+node_number))"

  bosh upload-release "$(bosh int bosh.yml -o misc/source-releases/bosh.yml --path /releases/name=bpm/url)" \
    --sha1 "$(bosh int bosh.yml -o misc/source-releases/bosh.yml --path /releases/name=bpm/sha1)"
  bosh upload-release "$(bosh int bosh.yml -o jumpbox-user.yml --path /releases/name=os-conf/url)" \
    --sha1 "$(bosh int bosh.yml -o jumpbox-user.yml --path /releases/name=os-conf/sha1)"
  bosh upload-release "$(bosh int bosh.yml -o docker/cpi.yml --path /releases/name=bosh-docker-cpi/url)" \
    --sha1 "$(bosh int bosh.yml -o docker/cpi.yml --path /releases/name=bosh-docker-cpi/sha1)"
popd
