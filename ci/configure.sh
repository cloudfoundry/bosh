#!/usr/bin/env bash

set -eu

branch="$(git rev-parse --abbrev-ref HEAD)"
pipeline="bosh"

lpass ls > /dev/null

if [[ "${branch}" != "master" ]]; then
  pipeline="bosh:${branch}"
fi

fly -t director set-pipeline -p "${pipeline}" \
    -c ci/pipeline.yml \
    -l <(lpass show -G "bosh concourse secrets" --notes) \
    -l <(lpass show --note "bats-concourse-pool:vsphere secrets") \
    -l <(lpass show --note "bats-concourse-pool:vsphere nimbus secrets" ) \
    -l <(lpass show --note "tracker-bot-story-delivery") \
    -l <(lpass show -G "bosh:aws-ubuntu-bats concourse secrets" --notes) \
    -l <(lpass show --note "bosh:docker-images concourse secrets") \
    --var=branch_name=${branch}
