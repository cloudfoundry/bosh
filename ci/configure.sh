#!/usr/bin/env bash
set -eu -o pipefail

if [[ -n "${DEBUG:-}" ]]; then
  set -x
fi

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

pipeline_name="bosh-director"
pipeline_yaml="${REPO_ROOT}/ci/pipeline.yml"

concourse_target="${CONCOURSE_TARGET:-bosh}"
fly="${FLY_CLI:-fly}"

until "${fly}" -t "${concourse_target}" status; do
  "${fly}" -t "${concourse_target}" login
  sleep 1
done

echo "Validating..."
"${fly}" validate-pipeline --strict --config "${pipeline_yaml}"
echo ""

echo "Configuring..."
"${fly}" -t "${concourse_target}" \
  set-pipeline \
    --pipeline "${pipeline_name}" \
    --config "${pipeline_yaml}"
