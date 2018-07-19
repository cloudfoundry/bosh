#!/bin/bash -exu

main() {
  local output_dir="$PWD/updated-bbl-state/"

  local build_dir="${PWD}"
  export ENV_ASSETS=$PWD/bosh-src/ci/acceptance

  pushd bbl-state
    bbl version
    bbl plan > bbl_plan.txt

    # Customize environment
    cp $ENV_ASSETS/*.sh .

    bbl --debug up

    cp bbl-state.json ${output_dir}

    eval "$(bbl print-env)"
    bosh upload-stemcell ${build_dir}/stemcell/*.tgz -n
    bosh -d zookeeper deploy --recreate ${build_dir}/zookeeper-release/manifests/zookeeper.yml -n
  popd
}

main

