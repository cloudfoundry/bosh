#!/usr/bin/env bash

set -eu

fly -t production set-pipeline -p bosh:263.x \
    -c ci/pipeline.yml \
    -l <(lpass show -G "bosh concourse secrets" --notes) \
    -l <(lpass show --note "bats-concourse-pool:vsphere secrets") \
    -l <(lpass show --note "bosh concourse 263.x secrets")
