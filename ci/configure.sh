#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

fly -t "${CONCOURSE_TARGET:-bosh}" set-pipeline -p bosh-director \
    -c "${REPO_ROOT}/ci/pipeline.yml" \
    --var=branch_name=main
