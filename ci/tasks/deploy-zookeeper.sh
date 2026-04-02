#!/usr/bin/env bash

set -e

bosh_repo_dir="$(realpath "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" && pwd)")"

state_path() { bosh-cli int director-state/director.yml --path="$1" ; }

function get_bosh_environment {
  if [[ -z $(state_path /instance_groups/name=bosh/networks/name=public/static_ips/0 2>/dev/null) ]]; then
    state_path /instance_groups/name=bosh/networks/name=default/static_ips/0 2>/dev/null
  else
    state_path /instance_groups/name=bosh/networks/name=public/static_ips/0 2>/dev/null
  fi
}

mv bosh-cli/bosh-cli-* /usr/local/bin/bosh-cli
chmod +x /usr/local/bin/bosh-cli

export BOSH_CLIENT="admin"
BOSH_CLIENT_SECRET=$(bosh-cli int director-state/director-creds.yml --path /admin_password)
BOSH_ENVIRONMENT=$(get_bosh_environment)
BOSH_CA_CERT=$(bosh-cli int director-state/director-creds.yml --path /director_ssl/ca)
export BOSH_ENVIRONMENT
export BOSH_CA_CERT
export BOSH_CLIENT_SECRET
export BOSH_NON_INTERACTIVE=true

bosh-cli update-cloud-config "bosh-deployment/${CPI}/cloud-config.yml" \
  --vars-file director-state/director-vars.json

bosh-cli upload-stemcell stemcell/*.tgz

MAX_DEPLOY_ATTEMPTS=${MAX_DEPLOY_ATTEMPTS:-3}
DEPLOY_RETRY_DELAY=${DEPLOY_RETRY_DELAY:-60}

for attempt in $(seq 1 "$MAX_DEPLOY_ATTEMPTS"); do
  echo "Deploy attempt ${attempt}/${MAX_DEPLOY_ATTEMPTS}..."
  set +e
  # DEPLOY_EXTRA_ARGS is intentionally unquoted to allow multiple space-separated arguments
  # shellcheck disable=SC2086
  bosh-cli -d zookeeper deploy --recreate ${DEPLOY_EXTRA_ARGS:-} \
    "${bosh_repo_dir}/ci/tasks/deploy-zookeeper/zookeeper-manifest.yml"
  deploy_exit=$?
  set -e

  if [ $deploy_exit -eq 0 ]; then
    echo "Deploy succeeded on attempt ${attempt}."
    break
  fi

  echo "Deploy failed on attempt ${attempt}."
  echo "Current VM state:"
  bosh-cli -d zookeeper vms || true
  if [ "${attempt}" -eq "${MAX_DEPLOY_ATTEMPTS}" ]; then
    echo "Deploy failed after ${MAX_DEPLOY_ATTEMPTS} attempts."
    exit 1
  fi
  echo "Waiting ${DEPLOY_RETRY_DELAY}s before retry..."
  sleep "${DEPLOY_RETRY_DELAY}"
done

bosh-cli -d zookeeper run-errand smoke-tests
