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

pushd "${BOSH_DEPLOYMENT_PATH}" > /dev/null
  inner_bosh_dir="/tmp/inner-bosh/director/${node_number}"
  mkdir -p "${inner_bosh_dir}"

  export BOSH_DIRECTOR_IP="10.245.0.$((10 + node_number))"

  bosh int bosh.yml \
    -o "${REPO_ROOT}/ci/dockerfiles/docker-cpi/inner-bosh-ops.yml" \
    -o "${BOSH_DEPLOYMENT_PATH}/jumpbox-user.yml" \
    -o "${BOSH_DEPLOYMENT_PATH}/experimental/bpm.yml" \
    -v director_name=docker-inner \
    -v internal_ip="${BOSH_DIRECTOR_IP}" \
    -v docker_host="${DOCKER_HOST}" \
    -v network=director_network \
    -v docker_tls="${DOCKER_CERTS}" \
    -v stemcell_os="${STEMCELL_OS}" \
    -o "${BOSH_DEPLOYMENT_PATH}/misc/source-releases/bosh.yml" \
    -o "${REPO_ROOT}/ci/dockerfiles/docker-cpi/latest-bosh-release.yml" \
    -o "${REPO_ROOT}/ci/dockerfiles/docker-cpi/deployment-name.yml" \
    -v deployment_name="bosh-${node_number}" \
    "${@:2}" > "${inner_bosh_dir}/bosh-director.yml"

  bosh -n deploy -d "bosh-${node_number}" "${inner_bosh_dir}/bosh-director.yml" --vars-store="${inner_bosh_dir}/creds.yml"

  # set up inner director
  export BOSH_ENVIRONMENT="docker-inner-director-${node_number}"
  export BOSH_CONFIG="${inner_bosh_dir}/config"
  BOSH_CLIENT_SECRET=$(bosh int "${inner_bosh_dir}/creds.yml" --path /admin_password)
  export BOSH_CLIENT_SECRET

  bosh int "${inner_bosh_dir}/creds.yml" --path /director_ssl/ca > "${inner_bosh_dir}/ca.crt"
  bosh -e "${BOSH_DIRECTOR_IP}" --ca-cert "${inner_bosh_dir}/ca.crt" alias-env "${BOSH_ENVIRONMENT}"

  bosh int "${inner_bosh_dir}/creds.yml" --path /jumpbox_ssh/private_key > "${inner_bosh_dir}/jumpbox_private_key.pem"
  chmod 600 "${inner_bosh_dir}/jumpbox_private_key.pem"

  inner_bosh_script="${inner_bosh_dir}/bosh"

  cat <<EOF > "${inner_bosh_script}"
#!/bin/bash

export BOSH_CONFIG="${BOSH_CONFIG}"
export BOSH_ENVIRONMENT="${BOSH_ENVIRONMENT}"
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET="${BOSH_CLIENT_SECRET}"
export BOSH_CA_CERT="${inner_bosh_dir}/ca.crt"

$(which bosh) "\$@"
EOF

  chmod +x "${inner_bosh_dir}/bosh"

  "${inner_bosh_script}" -n update-cloud-config \
    "${REPO_ROOT}/ci/dockerfiles/docker-cpi/inner-bosh-cloud-config.yml" \
    -v node_number="$((node_number * 4))" \
    -v network=director_network

popd > /dev/null
