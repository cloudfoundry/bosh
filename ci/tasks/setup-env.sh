#!/bin/bash -exu

main() {
  source bosh-src/ci/tasks/utils.sh

  local build_dir="${PWD}"
  local bbl_state_env_repo_dir=$PWD/bbl-state
  local output_dir="$PWD/updated-bbl-state/"
  local env_assets="$PWD/bosh-src/ci/acceptance"
  BBL_STATE_DIR=bosh-acceptance-env
  export BBL_STATE_DIR

  trap "commit_bbl_state_dir ${bbl_state_env_repo_dir} ${BBL_STATE_DIR} ${output_dir} 'Update bosh-acceptance-env environment'" EXIT

  mkdir -p bbl-state

  pushd bbl-state
    bbl version
    bbl plan > bbl_plan.txt

    # Customize environment
    cp $env_assets/*.sh .

    bbl --debug up

    set +x
    eval "$(bbl print-env)"
    set -x
    bosh upload-stemcell ${build_dir}/stemcell/*.tgz -n
    bosh -d zookeeper deploy --recreate ${build_dir}/zookeeper-release/manifests/zookeeper.yml -n
  popd
}

main "$@"
