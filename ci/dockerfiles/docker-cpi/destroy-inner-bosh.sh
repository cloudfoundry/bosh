#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

node_number=${1}
deployment_name="bosh-${node_number}"

inner_bosh_dir="/tmp/inner-bosh/director/${node_number}"
inner_bosh_cmd="${inner_bosh_dir}/bosh"

if [ ! -e "${inner_bosh_cmd}" ]; then
  echo "No '${inner_bosh_cmd}' found, exiting" >&2
  exit
fi

"${inner_bosh_cmd}" deployments --column=name \
  | awk '{ print $1 }' \
  | xargs -n1 -I {} -- "${inner_bosh_cmd}" -n -d {} delete-deployment --force

bosh -n delete-deployment -d "${deployment_name}"

rm -fr "${inner_bosh_dir}"
