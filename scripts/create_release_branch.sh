#!/usr/bin/env bash

main() {
  set -e

  local scripts_path=$(dirname $0)
  local start_point=${2:-'HEAD'}
  local release_patch_file=$scripts_path/create_release_branch.patch
  local finalize_job_patch_file=$scripts_path/add_finalize_release_job.patch

  local BRANCH_NAME=${1?'Branch name is required.'}

  git checkout -b ${BRANCH_NAME} $start_point

  sed  -e "s/-p bosh/-p bosh:${BRANCH_NAME}/" <(git show origin/master:ci/configure.sh) > ci/configure.sh

  BRANCH_VERSION=${OVERRIDE_VERSION:-$(echo ${BRANCH_NAME} | cut -d '.' -f1)}

  bosh int -o scripts/create-release-branch-ops.yml <(git show origin/master:ci/pipeline.yml) -v branchver=${BRANCH_VERSION} -v branchname=${BRANCH_NAME} > ci/pipeline.yml

  git add -A .
  git ci -m "Create release branch $BRANCH_NAME"

  echo "Branch created successfully. Run 'git push -u origin $BRANCH_NAME' to push branch to Github."

  echo -e "\n---------------------------\n"

  echo "Run './ci/configure.sh' when ready to push pipeline to Concourse."
}

main "$@"
