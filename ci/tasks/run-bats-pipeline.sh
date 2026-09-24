#!/usr/bin/env bash
# run-bats-pipeline.sh
#
# Chains together the full BATs pipeline in a single Concourse task:
#   terraform apply  → deploy-director → prepare-bats-config → run-bats
#   terraform destroy ← destroy-director  ←  (EXIT trap, always runs)
#
# Required env vars (set via run-bats-pipeline.yml params):
#   GCP_JSON_KEY      – GCP service account JSON (resolved from Concourse creds)
#   GCP_PROJECT_ID    – GCP project ID
#   ENV_NAME          – Unique terraform env name, e.g. "bats-local"
#   BAT_INFRASTRUCTURE – "gcp"
#   STEMCELL_NAME     – Stemcell name for bats-config.yml
#   DEPLOY_ARGS       – Extra ops-file args for bosh create-env
#   BAT_RSPEC_FLAGS   – Extra flags appended to the BAT run (optional)

set -eu

ROOT_DIR="$PWD"
TERRAFORM_DIR="${ROOT_DIR}/bosh-ci/ci/bats/iaas/gcp/terraform"
TERRAFORM_VERSION="1.9.8"

# ── Shared working directories ───────────────────────────────────────────────
mkdir -p director-state bats-config environment
# cache-dot-bosh-dir is provided as a Concourse cache volume; create if absent
mkdir -p cache-dot-bosh-dir/.bosh

# prepare-bats-config.sh expects its terraform metadata at terraform/metadata
# but deploy-director.sh expects it at environment/metadata.
# Symlink terraform/ → environment/ so both scripts find what they need.
ln -sf "${ROOT_DIR}/environment" "${ROOT_DIR}/terraform"

# ── Install terraform ────────────────────────────────────────────────────────
if ! command -v terraform &>/dev/null; then
  echo "--- Installing terraform ${TERRAFORM_VERSION} ---"
  curl -sSL \
    "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    -o /tmp/terraform.zip
  unzip -qo /tmp/terraform.zip -d /usr/local/bin terraform
  chmod +x /usr/local/bin/terraform
fi

# ── GCP credentials file (used by the GCS backend and the Google provider) ──
GCP_CREDS_FILE="$(mktemp /tmp/gcp-creds-XXXXXX.json)"
echo "${GCP_JSON_KEY}" > "${GCP_CREDS_FILE}"
chmod 600 "${GCP_CREDS_FILE}"

# ── Provision GCP environment via terraform ──────────────────────────────────
echo "--- Provisioning GCP environment (env: ${ENV_NAME}) ---"
pushd "${TERRAFORM_DIR}" >/dev/null

terraform init \
  -input=false \
  -reconfigure \
  -backend-config="bucket=bosh-director-pipeline" \
  -backend-config="prefix=bats-terraform/${ENV_NAME}" \
  -backend-config="credentials=${GCP_CREDS_FILE}"

terraform apply \
  -input=false \
  -auto-approve \
  -var "project_id=${GCP_PROJECT_ID}" \
  -var "gcp_credentials_json=${GCP_JSON_KEY}" \
  -var "name=${ENV_NAME}"

# Convert terraform outputs to the flat metadata JSON consumed by director-vars
# and prepare-bats-config.sh.
terraform output -json \
  | jq 'with_entries(.value = .value.value)' \
  > "${ROOT_DIR}/environment/metadata"

popd >/dev/null

# ── Teardown trap (always runs on EXIT) ─────────────────────────────────────
function collect_director_diagnostics {
  # Only collect when we have a deployed director and bosh-cli is available.
  [[ -f director-state/director-creds.yml ]] || return 0
  [[ -f "${ROOT_DIR}/environment/metadata" ]] || return 0
  command -v bosh-cli &>/dev/null || return 0

  local director_ip
  director_ip="$(jq -r '.director_public_ip // empty' "${ROOT_DIR}/environment/metadata")"
  [[ -n "${director_ip}" ]] || return 0

  echo "--- Collecting director diagnostics (IP: ${director_ip}) ---"

  # Extract jumpbox SSH private key from the vars-store.
  local jumpbox_key_file
  jumpbox_key_file="$(mktemp /tmp/jumpbox-key-XXXXXX)"
  bosh-cli interpolate director-state/director-creds.yml \
    --path /jumpbox_ssh/private_key > "${jumpbox_key_file}" 2>/dev/null || { rm -f "${jumpbox_key_file}"; return 0; }
  chmod 600 "${jumpbox_key_file}"

  ssh -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      -i "${jumpbox_key_file}" \
      "jumpbox@${director_ip}" \
    'echo "=== monit status ===" && sudo /var/vcap/bosh/bin/monit status;
     echo "=== bosh_nats_sync log (last 100 lines) ===" && sudo tail -100 /var/vcap/sys/log/nats/bosh-nats-sync.log 2>/dev/null || true;
     echo "=== bosh_nats_sync bpm stdout ===" && sudo cat /var/vcap/sys/log/bpm/nats/bosh_nats_sync.stdout.log 2>/dev/null || true;
     echo "=== bosh_nats_sync bpm stderr ===" && sudo cat /var/vcap/sys/log/bpm/nats/bosh_nats_sync.stderr.log 2>/dev/null || true;
     echo "=== nats log (last 50 lines) ===" && sudo tail -50 /var/vcap/sys/log/nats/nats.log 2>/dev/null || true;
     echo "=== nats bpm stdout (last 50 lines) ===" && sudo tail -50 /var/vcap/sys/log/bpm/nats/nats.stdout.log 2>/dev/null || true;
     echo "=== health_monitor log (last 100 lines) ===" && sudo tail -100 /var/vcap/sys/log/health_monitor/health_monitor.log 2>/dev/null || true;
     echo "=== health_monitor bpm stdout ===" && sudo tail -50 /var/vcap/sys/log/bpm/health_monitor/health_monitor.stdout.log 2>/dev/null || true;
     echo "=== health_monitor bpm stderr ===" && sudo tail -50 /var/vcap/sys/log/bpm/health_monitor/health_monitor.stderr.log 2>/dev/null || true' \
    2>&1 || echo "(SSH diagnostics failed — VM may not be reachable)"

  rm -f "${jumpbox_key_file}"
}

function teardown {
  local exit_code=$?
  set +e

  # Always collect diagnostics – on success this helps correlate logs with
  # passing runs; on failure it captures the state at the point of failure.
  collect_director_diagnostics

  echo "--- Tearing down BOSH director ---"
  if [[ -f director-state/director-state.json ]]; then
    # destroy-director.sh expects bosh-cli/bosh-cli-* to exist; restore it
    # because deploy-director.sh already moved the original binary away.
    cp /usr/local/bin/bosh-cli bosh-cli/bosh-cli-restore 2>/dev/null || true
    bosh-ci/ci/bats/tasks/destroy-director.sh || true
  fi

  echo "--- Destroying GCP environment (env: ${ENV_NAME}) ---"
  pushd "${TERRAFORM_DIR}" >/dev/null
  terraform destroy \
    -input=false \
    -auto-approve \
    -var "project_id=${GCP_PROJECT_ID}" \
    -var "gcp_credentials_json=${GCP_JSON_KEY}" \
    -var "name=${ENV_NAME}" || true
  popd >/dev/null

  rm -f "${GCP_CREDS_FILE}"

  exit "${exit_code}"
}
trap teardown EXIT

# ── Deploy BOSH director ─────────────────────────────────────────────────────
echo "--- Deploying BOSH director ---"
# deploy-director.sh moves bosh-cli/bosh-cli-* to /usr/local/bin/bosh-cli.
# After this call bosh-cli is installed system-wide as 'bosh-cli'.
bosh-ci/ci/bats/tasks/deploy-director.sh

# ── Prepare BATs config ──────────────────────────────────────────────────────
echo "--- Preparing BATs config ---"
bosh-ci/ci/bats/iaas/gcp/prepare-bats-config.sh

# ── Run BATs ─────────────────────────────────────────────────────────────────
echo "--- Running BATs ---"
# Source the environment file that prepare-bats-config.sh wrote; this exports
# BOSH_ENVIRONMENT, BOSH_CLIENT, BOSH_CLIENT_SECRET, BOSH_CA_CERT,
# BOSH_ALL_PROXY, and the default BAT_RSPEC_FLAGS.
# shellcheck source=/dev/null
source bats-config/bats.env

# Allow the caller to append extra RSpec flags (e.g. "--tag wip").
if [[ -n "${BAT_RSPEC_FLAGS:-}" ]]; then
  export BAT_RSPEC_FLAGS="${BAT_RSPEC_FLAGS}"
fi

bats/ci/tasks/run-bats.sh
