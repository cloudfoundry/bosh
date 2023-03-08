#!/usr/bin/env bash

set -e

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
bosh_path="${bosh_release_path:-${script_dir}/../../../}"
bosh_release_path=""
src_dir="${script_dir}/../../../"

pushd "${bosh_path}" > /dev/null
  if [[ ! -e $(find . -maxdepth 1 -name "*.tgz") ]]; then
    bosh reset-release
    bosh create-release --force --tarball release.tgz
  fi

  bosh_release_path="$(realpath "$(find . -maxdepth 1 -name "*.tgz")")"
popd > /dev/null

bosh upload-release ${bosh_release_path} --name=bosh


pushd "${src_dir}/src/go/src/github.com/cloudfoundry/bosh-release-acceptance-tests/assets/linked-templates-release" > /dev/null
  if [[ ! -e $(find . -maxdepth 1 -name "*.tgz") ]]; then
    bosh reset-release
    bosh create-release --force --tarball release.tgz
  fi
popd > /dev/null

pushd ${BOSH_DEPLOYMENT_PATH} > /dev/null
  inner_bosh_dir="/tmp/inner-bosh/director/$node_number"
  node_number=$1
  if [[ -n "$node_number" ]]; then
    inner_bosh_dir="/tmp/inner-bosh/director/${node_number}"
  fi

  mkdir -p ${inner_bosh_dir}

  export BOSH_DIRECTOR_IP="10.245.0.$((10+$node_number))"

  bosh upload-release "$(bosh int bosh.yml -o misc/source-releases/bosh.yml --path /releases/name=bpm/url)" \
    --sha1 "$(bosh int bosh.yml -o misc/source-releases/bosh.yml --path /releases/name=bpm/sha1)"
  bosh upload-release "$(bosh int bosh.yml -o jumpbox-user.yml --path /releases/name=os-conf/url)" \
    --sha1 "$(bosh int bosh.yml -o jumpbox-user.yml --path /releases/name=os-conf/sha1)"
  bosh upload-release https://bosh.io/d/github.com/cppforlife/bosh-docker-cpi-release?v=0.0.10 --sha1 71c14a2fd90b52e980f95d400c5e64a3a920b417
popd > /dev/null
