#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

BOSH_DEPLOYMENT_PATH="${BOSH_DEPLOYMENT_PATH:-/usr/local/bosh-deployment}"

BOSH_DIRECTOR_IP="10.245.0.3"
BOSH_ENVIRONMENT="docker-director"

function main() {
  # Brings up the docker daemon and exports DOCKER_HOST, DOCKER_NETWORK_NAME,
  # DOCKER_NETWORK_CIDR and DOCKER_TLS_JSON.
  # shellcheck disable=SC1091
  source /usr/local/bin/start-docker

  local local_bosh_dir
  local_bosh_dir="/tmp/local-bosh/director"

  # shellcheck disable=SC2068,SC2086
  bosh int "${BOSH_DEPLOYMENT_PATH}/bosh.yml" \
    -o "${BOSH_DEPLOYMENT_PATH}/docker/cpi.yml" \
    -o "${BOSH_DEPLOYMENT_PATH}/jumpbox-user.yml" \
    -o /usr/local/ops-files/local-releases.yml \
    ${ADDITIONAL_DIRECTOR_OPS_FILES:-} \
    -v director_name=docker \
    -v internal_cidr="${DOCKER_NETWORK_CIDR}" \
    -v internal_gw=10.245.0.1 \
    -v internal_ip="${BOSH_DIRECTOR_IP}" \
    -v docker_host="${DOCKER_HOST}" \
    -v network="${DOCKER_NETWORK_NAME}" \
    -v docker_tls="$(cat "${DOCKER_TLS_JSON}")" \
    ${@} > "${local_bosh_dir}/bosh-director.yml"

  bosh create-env "${local_bosh_dir}/bosh-director.yml" \
      --vars-store="${local_bosh_dir}/creds.yml" \
      --state="${local_bosh_dir}/state.json"

  bosh int "${local_bosh_dir}/creds.yml" --path /director_ssl/ca > "${local_bosh_dir}/ca.crt"
  bosh_client_secret="$(bosh int "${local_bosh_dir}/creds.yml" --path /admin_password)"

  mbus_bootstrap_cert="$(bosh int "${local_bosh_dir}/creds.yml" --path /mbus_bootstrap_ssl/certificate)"
  mbus_bootstrap_pass="$(bosh int "${local_bosh_dir}/creds.yml" --path /mbus_bootstrap_password)"

  bosh -e "${BOSH_DIRECTOR_IP}" --ca-cert "${local_bosh_dir}/ca.crt" alias-env "${BOSH_ENVIRONMENT}"

  bosh_env_file="${local_bosh_dir}/bosh-env"
  {
    echo "source \"${local_bosh_dir}/docker-env\""
    echo "export BOSH_DIRECTOR_IP=\"${BOSH_DIRECTOR_IP}\""
    echo "export BOSH_ENVIRONMENT=\"${BOSH_ENVIRONMENT}\""
    echo "export BOSH_CLIENT=\"admin\""
    echo "export BOSH_CLIENT_SECRET=\"${bosh_client_secret}\""
    echo "export BOSH_CA_CERT=\"${local_bosh_dir}/ca.crt\""
    echo "export BOSH_AGENT_CERTIFICATE=\"${mbus_bootstrap_cert}\""
    echo "export BOSH_AGENT_ENDPOINT=\"https://mbus:${mbus_bootstrap_pass}@${BOSH_DIRECTOR_IP}:6868\""
  } > "${bosh_env_file}"

  echo "Source '${bosh_env_file}' to run bosh" >&2
  # shellcheck disable=SC1090
  source "${bosh_env_file}"

  bosh -n update-cloud-config \
    "${BOSH_DEPLOYMENT_PATH}/docker/cloud-config.yml" \
    -o "/usr/local/ops-files/gcp-internal-dns-ops.yml" \
    -v network="${DOCKER_NETWORK_NAME}"
}

# shellcheck disable=SC2068
main ${@}
