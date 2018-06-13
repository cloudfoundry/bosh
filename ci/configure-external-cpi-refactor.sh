#!/usr/bin/env bash

set -eu

fly -t production set-pipeline -p bosh:registry-removal \
    -c ci/pipeline-external-cpi-refactor.yml \
    --load-vars-from <(lpass show -G "bosh concourse secrets" --notes) \
    --load-vars-from <(lpass show -G "bosh aws cpi v2 ci secrets" --notes)
