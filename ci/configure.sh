#!/usr/bin/env bash

set -eu

fly -t "${CONCOURSE_TARGET:-bosh}" set-pipeline -p bosh-director \
    -c ci/pipeline.yml \
    --var=branch_name=main
