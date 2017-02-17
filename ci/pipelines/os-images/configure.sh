#!/usr/bin/env bash

set -eu

fly -t production set-pipeline -p bosh:os-image \
    -c ci/pipelines/os-images/pipeline.yml \
    --load-vars-from <(lpass show -G "concourse:production pipeline:os-images" --notes)
