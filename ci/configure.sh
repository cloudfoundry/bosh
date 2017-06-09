#!/usr/bin/env bash

set -eu

fly -t production set-pipeline -p bosh:262.x \
    -c ci/pipeline.yml \
    --load-vars-from <(lpass show -G "bosh concourse secrets" --notes) \
    --load-vars-from <(lpass show --note "bats-concourse-pool:vsphere secrets") \
    --load-vars-from <(lpass show --note "bosh concourse 262.x secrets")
