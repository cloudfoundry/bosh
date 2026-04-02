#!/usr/bin/env bash
set -e

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

MAX_ATTEMPTS=60
SLEEP_INTERVAL=10
TOTAL_TIMEOUT=$((MAX_ATTEMPTS * SLEEP_INTERVAL))

echo "Waiting up to ${TOTAL_TIMEOUT}s for all zookeeper agents to become responsive..."

for i in $(seq 1 "${MAX_ATTEMPTS}"); do
  set +e
  vms_json=$(bosh-cli -d zookeeper vms --json)
  exit_code=$?
  set -e

  if [ $exit_code -eq 0 ]; then
    zookeeper_instances_json=$(echo "${vms_json}" | jq -r '[.Tables[0].Rows[] | select(.instance | startswith("zookeeper/"))]')
    total=$(echo "${zookeeper_instances_json}" | jq -r '. | length')
    running=$(echo "${zookeeper_instances_json}" | jq -r '[.[] | select(.process_state == "running")] | length')

    echo "  Attempt $i/${MAX_ATTEMPTS}: ${running}/${total} agents responsive"

    if [ "$running" -eq "$total" ] && [ "$total" -gt 0 ]; then
      echo "All ${total} agents are responsive after $(((i - 1) * SLEEP_INTERVAL)) seconds."
      exit 0
    fi
  else
    echo "  Attempt $i/${MAX_ATTEMPTS}: bosh vms failed (director may still be starting)"
  fi

  sleep "${SLEEP_INTERVAL}"
done

echo "ERROR: Not all agents became responsive within ${TOTAL_TIMEOUT}s."
echo "Final VM state:"
bosh-cli -d zookeeper vms || true
exit 1
