#!/bin/bash -exu

save_state() {
  local output_dir=$1
  cp bbl-state.json "${output_dir}"
}

main() {
  local build_dir="${PWD}"
  local output_dir="$PWD/updated-bbl-state/"
  local env_assets="$PWD/bosh-src/ci/acceptance"

  trap "save_state ${output_dir}" EXIT

  mkdir -p bbl-state

  pushd bbl-state
    bbl version
    bbl plan > bbl_plan.txt

    # Customize environment
    cp $env_assets/*.sh .

    bbl --debug up

    eval "$(bbl print-env)"
    bosh upload-stemcell ${build_dir}/stemcell/*.tgz -n
    bosh -d zookeeper deploy --recreate ${build_dir}/zookeeper-release/manifests/zookeeper.yml -n
  popd
}

main "$@"

