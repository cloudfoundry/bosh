#!/usr/bin/env bash

set -eu

branch="master"

fly -t production set-pipeline -p bosh \
    -c ci/pipeline.yml \
    --load-vars-from <(lpass show -G "bosh concourse secrets" --notes) \
    -l <(lpass show --note "bats-concourse-pool:vsphere secrets") \
    -l <(lpass show --note "tracker-bot-story-delivery") \
    --var=branch_name=${branch}
