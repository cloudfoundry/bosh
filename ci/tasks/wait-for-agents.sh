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

# Phase 1: wait for all agents to appear in "running" state in the director DB.
# bosh vms reads last-known heartbeat state — it does NOT send a live get_state to each
# agent. So this phase only confirms that agents have reconnected to NATS after the
# director upgrade; it does not guarantee the agents can handle a live get_state request.
MAX_ATTEMPTS=60
SLEEP_INTERVAL=10
TOTAL_TIMEOUT=$((MAX_ATTEMPTS * SLEEP_INTERVAL))

echo "Phase 1: Waiting up to ${TOTAL_TIMEOUT}s for all zookeeper agents to appear running..."

total=0
phase1_success=false
for i in $(seq 1 "${MAX_ATTEMPTS}"); do
  set +e
  vms_json=$(bosh-cli -d zookeeper vms --json)
  exit_code=$?
  set -e

  if [ $exit_code -eq 0 ]; then
    zookeeper_instances_json=$(echo "${vms_json}" | jq -r '[.Tables[0].Rows[] | select(.instance | startswith("zookeeper/"))]')
    total=$(echo "${zookeeper_instances_json}" | jq -r '. | length')
    running=$(echo "${zookeeper_instances_json}" | jq -r '[.[] | select(.process_state == "running")] | length')

    echo "  Attempt $i/${MAX_ATTEMPTS}: ${running}/${total} agents in running state"

    if [ "$running" -eq "$total" ] && [ "$total" -gt 0 ]; then
      echo "All ${total} agents appear running after $(((i - 1) * SLEEP_INTERVAL)) seconds."
      phase1_success=true
      break
    fi
  else
    echo "  Attempt $i/${MAX_ATTEMPTS}: bosh vms failed (director may still be starting)"
  fi

  sleep "${SLEEP_INTERVAL}"
done

if [ "${phase1_success}" != "true" ]; then
  echo "ERROR: Not all agents became running within ${TOTAL_TIMEOUT}s."
  echo "Final VM state:"
  bosh-cli -d zookeeper vms || true
  exit 1
fi

# Phase 2: verify live agent responsiveness and ZK process health.
# bosh instances --ps sends a live list_processes to each agent via NATS.
# This confirms the agent can handle live director commands (the same code-path that
# bosh deploy --recreate exercises during "Preparing deployment" with get_state).
# It also confirms that the ZK process itself is up inside each instance — preventing
# smoke-tests from running against a cluster still in leader election.
PROC_MAX_ATTEMPTS=30
PROC_SLEEP_INTERVAL=10
PROC_TOTAL_TIMEOUT=$((PROC_MAX_ATTEMPTS * PROC_SLEEP_INTERVAL))

echo "Phase 2: Waiting up to ${PROC_TOTAL_TIMEOUT}s for ZK processes to be healthy (live agent check)..."

for j in $(seq 1 "${PROC_MAX_ATTEMPTS}"); do
  set +e
  instances_json=$(bosh-cli -d zookeeper instances --ps --json)
  proc_exit=$?
  set -e

  if [ $proc_exit -eq 0 ]; then
    # Process-level rows have .process == "zookeeper"; instance-level rows have .process == "".
    zk_proc_total=$(echo "${instances_json}" | jq '[.Tables[].Rows[] | select((.process // "") == "zookeeper")] | length')
    zk_proc_running=$(echo "${instances_json}" | jq '[.Tables[].Rows[] | select((.process // "") == "zookeeper") | select(.process_state == "running")] | length')

    echo "  Attempt $j/${PROC_MAX_ATTEMPTS}: ${zk_proc_running}/${zk_proc_total} ZK processes healthy"

    if [ "${zk_proc_running}" -eq "${total}" ] && [ "${zk_proc_total}" -eq "${total}" ] && [ "${total}" -gt 0 ]; then
      echo "All ${total} ZK processes are healthy after $(((j - 1) * PROC_SLEEP_INTERVAL)) seconds."
      exit 0
    fi
  else
    echo "  Attempt $j/${PROC_MAX_ATTEMPTS}: bosh instances --ps failed (agent may not be fully ready)"
  fi

  sleep "${PROC_SLEEP_INTERVAL}"
done

echo "ERROR: Not all ZK processes became healthy within ${PROC_TOTAL_TIMEOUT}s."
echo "Final instance state:"
bosh-cli -d zookeeper instances --ps || true
exit 1
