#!/usr/bin/env bash

set -eu

lpass ls > /dev/null

fly -t "${CONCOURSE_TARGET:-bosh-ecosystem}" set-pipeline -p bosh-director \
    -c ci/pipeline.yml \
    -l <(lpass show -G "bosh concourse secrets" --notes) \
    -l <(lpass show --note "bats-concourse-pool:vsphere secrets") \
    -l <(lpass show --note "tracker-bot-story-delivery") \
    -l <(lpass show -G "bosh:aws-ubuntu-bats concourse secrets" --notes) \
    --var=branch_name=main
