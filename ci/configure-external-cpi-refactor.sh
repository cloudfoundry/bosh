#!/usr/bin/env bash

set -eu

fly -t production set-pipeline -p bosh:external-cpi-refactor \
    -c ci/pipeline-external-cpi-refactor.yml \
    --load-vars-from <(lpass show -G "bosh concourse secrets" --notes)
