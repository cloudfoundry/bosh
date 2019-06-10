#!/usr/bin/env bash

set -eu

branch="$(git rev-parse --abbrev-ref HEAD)"
pipeline="bosh"

if [[ $(lpass status -q; echo $?) != 0 ]]; then
  echo "Login with lpass first"
  exit 1
fi

if [[ "${branch}" != "master" ]]; then
  pipeline="bosh:${branch}"
fi

fly -t director set-pipeline -p "${pipeline}" \
    -c ci/pipeline.yml \
    --load-vars-from <(lpass show -G "bosh concourse secrets" --notes) \
    -l <(lpass show --note "bats-concourse-pool:vsphere secrets") \
    -l <(lpass show --note "tracker-bot-story-delivery") \
    -l <(lpass show -G "bosh:aws-ubuntu-bats concourse secrets" --notes) \
    --var=branch_name=${branch}
