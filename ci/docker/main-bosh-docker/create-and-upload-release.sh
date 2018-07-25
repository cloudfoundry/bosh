#!/usr/bin/env bash

set -e

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
bosh_path="${bosh_release_path:-${script_dir}/../../../}"
bosh_release_path=""
src_dir="${script_dir}/../../../"

pushd "${bosh_path}" > /dev/null
  if [[ ! -e $(find . -maxdepth 1 -name "*.tgz") ]]; then
    bosh create-release --tarball release.tgz
  fi

  bosh_release_path="$(realpath "$(find . -maxdepth 1 -name "*.tgz")")"
popd > /dev/null

bosh upload-release ${bosh_release_path} --name=bosh

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
  bosh upload-release "$(bosh int bosh.yml -o bbr.yml --path /releases/name=backup-and-restore-sdk/url)" \
    --sha1 "$(bosh int bosh.yml -o bbr.yml --path /releases/name=backup-and-restore-sdk/sha1)"
  bosh upload-release https://bosh.io/d/github.com/cppforlife/bosh-docker-cpi-release?v=0.0.5 --sha1 075bc0264d2548173da55a40127757ae962a25b1
  bosh upload-release https://bosh.io/d/github.com/cloudfoundry/bosh?v=261.5 --sha1 14cc92601a746e41e9b1fc1e27f94099b51426ce
  bosh upload-release https://bosh.io/d/github.com/cloudfoundry/bosh?v=264.7.0 --sha1 11433d7530eea34d9ae2385ce2a7cb13912928bf
popd > /dev/null
