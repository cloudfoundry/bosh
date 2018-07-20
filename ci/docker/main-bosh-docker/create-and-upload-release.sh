#!/usr/bin/env bash

set -eu

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
