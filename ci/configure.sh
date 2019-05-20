#!/usr/bin/env bash

set -eu

fly -t pcf set-pipeline -p bosh:266.x \
    -c ci/pipeline.yml \
    -l <(lpass show --note "concourse:production pipeline:bosh:stemcells lts") \
    -l <(lpass show -G "bosh concourse secrets" --notes) \
    -l <(lpass show --note "bats-concourse-pool:vsphere secrets") \
    -l <(lpass show --note "bosh-lts concourse secrets") \
    -l <(lpass show --note "tracker-bot-story-delivery")
