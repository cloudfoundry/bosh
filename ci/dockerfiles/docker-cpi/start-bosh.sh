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

# Release tarballs baked into the image, each with a <name>.sha1 next to it.
LOCAL_RELEASES_DIR="${LOCAL_RELEASES_DIR:-/usr/local/releases}"

function interpolate_director_manifest() {
  local local_releases_ops="${1}"
  shift

  # shellcheck disable=SC2086
  bosh int "${BOSH_DEPLOYMENT_PATH}/bosh.yml" \
    -o "${BOSH_DEPLOYMENT_PATH}/docker/cpi.yml" \
    -o "${BOSH_DEPLOYMENT_PATH}/jumpbox-user.yml" \
    -o "${BOSH_DEPLOYMENT_PATH}/uaa.yml" \
    -o "${BOSH_DEPLOYMENT_PATH}/credhub.yml" \
    -o "${local_releases_ops}" \
    ${ADDITIONAL_DIRECTOR_OPS_FILES:-} \
    -v director_name=docker \
    -v internal_cidr="${DOCKER_NETWORK_CIDR}" \
    -v internal_gw=10.245.0.1 \
    -v internal_ip="${BOSH_DIRECTOR_IP}" \
    -v docker_host="${DOCKER_HOST}" \
    -v network="${DOCKER_NETWORK_NAME}" \
    -v docker_tls="$(cat "${DOCKER_TLS_JSON}")" \
    "$@"
}

# Writes an ops file pointing each release at its baked-in tarball, but only
# where the manifest's sha1 matches the tarball's. create-env doesn't check the
# sha1 of file:// releases, so without this a BOSH_DEPLOYMENT_PATH newer than
# the image's would silently get older releases. Mismatches are downloaded.
function write_local_releases_ops() {
  local manifest="${1}" ops_file="${2}"
  local sha1_file name manifest_sha1 ops=""

  for sha1_file in "${LOCAL_RELEASES_DIR}"/*.sha1; do
    [[ -e "${sha1_file}" ]] || continue
    name="$(basename "${sha1_file}" .sha1)"
    manifest_sha1="$(bosh int "${manifest}" --path "/releases/name=${name}/sha1" 2>/dev/null || true)"
    if [[ "${manifest_sha1}" == "$(cat "${sha1_file}")" ]]; then
      ops+="- type: replace
  path: /releases/name=${name}/url
  value: file://${LOCAL_RELEASES_DIR}/${name}.tgz
"
    else
      echo "Not using the baked-in ${name} release: its sha1 doesn't match the manifest's ('${manifest_sha1:-none}')" >&2
    fi
  done

  echo "${ops:-[]}" > "${ops_file}"
}

function main() {
  # Brings up the docker daemon and exports DOCKER_HOST, DOCKER_NETWORK_NAME,
  # DOCKER_NETWORK_CIDR and DOCKER_TLS_JSON.
  # shellcheck disable=SC1091
  source /usr/local/bin/start-docker

  local local_bosh_dir
  local_bosh_dir="/tmp/local-bosh/director"

  local local_releases_ops="${local_bosh_dir}/local-releases.yml"
  echo "[]" > "${local_releases_ops}"
  interpolate_director_manifest "${local_releases_ops}" "$@" > "${local_bosh_dir}/bosh-director.yml"
  write_local_releases_ops "${local_bosh_dir}/bosh-director.yml" "${local_releases_ops}"
  interpolate_director_manifest "${local_releases_ops}" "$@" > "${local_bosh_dir}/bosh-director.yml"

  bosh create-env "${local_bosh_dir}/bosh-director.yml" \
      --vars-store="${local_bosh_dir}/creds.yml" \
      --state="${local_bosh_dir}/state.json"

  # Keep credentials out of the caller's xtrace output (and DEBUG's).
  local xtrace_was_on=false
  if [[ $- == *x* ]]; then
    xtrace_was_on=true
  fi
  { set +x; } 2>/dev/null

  bosh int "${local_bosh_dir}/creds.yml" --path /director_ssl/ca > "${local_bosh_dir}/ca.crt"
  bosh_client_secret="$(bosh int "${local_bosh_dir}/creds.yml" --path /admin_password)"

  mbus_bootstrap_cert="$(bosh int "${local_bosh_dir}/creds.yml" --path /mbus_bootstrap_ssl/certificate)"
  mbus_bootstrap_pass="$(bosh int "${local_bosh_dir}/creds.yml" --path /mbus_bootstrap_password)"

  bosh int "${local_bosh_dir}/creds.yml" --path /credhub_tls/ca > "${local_bosh_dir}/credhub-ca.crt"
  bosh int "${local_bosh_dir}/creds.yml" --path /uaa_ssl/ca >> "${local_bosh_dir}/credhub-ca.crt"
  credhub_secret="$(bosh int "${local_bosh_dir}/creds.yml" --path /credhub_admin_client_secret)"

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
    echo "export CREDHUB_SERVER=\"https://${BOSH_DIRECTOR_IP}:8844\""
    echo "export CREDHUB_CLIENT=\"credhub-admin\""
    echo "export CREDHUB_SECRET=\"${credhub_secret}\""
    echo "export CREDHUB_CA_CERT=\"${local_bosh_dir}/credhub-ca.crt\""
  } > "${bosh_env_file}"

  echo "Source '${bosh_env_file}' to run bosh" >&2
  # shellcheck disable=SC1090
  source "${bosh_env_file}"

  if [[ "${xtrace_was_on}" == true ]]; then
    set -x
  fi

  bosh -n update-cloud-config \
    "${BOSH_DEPLOYMENT_PATH}/docker/cloud-config.yml" \
    -o "/usr/local/ops-files/gcp-internal-dns-ops.yml" \
    -o "/usr/local/ops-files/static-ips-ops.yml" \
    -v network="${DOCKER_NETWORK_NAME}"
}

main "$@"
