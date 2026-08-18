#!/bin/bash

set -euo 'pipefail'

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
src_dir="${script_dir}/../../.."

BOSH_RELEASE_PATH="${PWD}/bosh-release/$(basename bosh-release/*.tgz)"
export BOSH_RELEASE_PATH

mkdir -p bbr-binary
export BBR_BINARY_PATH="${PWD}/bbr-binary/bbr"
cp bbr-cli-binary/bbr-[0-9]*-linux-amd64 "${BBR_BINARY_PATH}"
chmod +x "${BBR_BINARY_PATH}"

export OVERRIDDEN_BOSH_DEPLOYMENT="${src_dir}/bosh-deployment"
if [[ -e ${OVERRIDDEN_BOSH_DEPLOYMENT}/bosh.yml ]];then
  export BOSH_DEPLOYMENT_PATH=${OVERRIDDEN_BOSH_DEPLOYMENT}
else
  export BOSH_DEPLOYMENT_PATH=/usr/local/bosh-deployment
fi

STEMCELL_PATH="${PWD}/stemcell/$(basename stemcell/*.tgz)"
STEMCELL_SHA1=$(sha1sum "${STEMCELL_PATH}" | awk '{print $1}')

STEMCELL_OS="$(tar -Oxzf "${STEMCELL_PATH}" stemcell.MF \
  | awk '/^operating_system:/ {gsub(/"/, "", $2); print $2}')"
if [[ -z "${STEMCELL_OS}" ]]; then
  echo "no operating_system in $(basename "${STEMCELL_PATH}")'s stemcell.MF" >&2
  exit 1
fi

cat > "${BOSH_DEPLOYMENT_PATH}/local-stemcell.yml" <<'OPSEOF'
- name: stemcell
  path: /resource_pools/name=vms/stemcell?
  type: replace
  value:
    url: ((local_stemcell_url))
    sha1: ((local_stemcell_sha1))
OPSEOF

director_ops_args=()
for f in ${DIRECTOR_OPS_FILES}; do
  director_ops_args+=(-o "${BOSH_DEPLOYMENT_PATH}/${f}")
done

# uaa.yml, credhub.yml and bbr.yml append releases, so DIRECTOR_OPS_FILES comes
# after them to rewrite those URLs too. The candidate release and the stemcell
# under test come last, so no earlier ops file can replace the artifacts being
# tested.
#
# Sourced rather than executed so the docker service can be stopped on exit; 
# see ci/dockerfiles/docker-cpi/README.md.
source start-bosh \
  -o "${BOSH_DEPLOYMENT_PATH}/uaa.yml" \
  -o "${BOSH_DEPLOYMENT_PATH}/credhub.yml" \
  -o "${BOSH_DEPLOYMENT_PATH}/bbr.yml" \
  -o "${BOSH_DEPLOYMENT_PATH}/hm/disable.yml" \
  "${director_ops_args[@]+"${director_ops_args[@]}"}" \
  -o "${BOSH_DEPLOYMENT_PATH}/local-bosh-release-tarball.yml" \
  -o "${BOSH_DEPLOYMENT_PATH}/local-stemcell.yml" \
  -v local_bosh_release="${BOSH_RELEASE_PATH}"\
  -v local_stemcell_url="file://${STEMCELL_PATH}" \
  -v local_stemcell_sha1="${STEMCELL_SHA1}"

source /tmp/local-bosh/director/bosh-env

# check that the items being tested are the local copies
for path in /releases/name=bosh/url /resource_pools/name=vms/stemcell/url; do
  url="$(bosh int /tmp/local-bosh/director/bosh-director.yml --path "${path}")"
  if [[ "${url}" != file://* ]]; then
    echo "expected ${path} to be a local file, got '${url}'" >&2
    exit 1
  fi
done

BOSH_SSH_KEY="$(bosh int /tmp/local-bosh/director/creds.yml --path /jumpbox_ssh/private_key --json | jq .Blocks[0])"
BOSH_HOST="${BOSH_DIRECTOR_IP}"

bosh_ca_cert_json_value="$(awk '{printf "%s\\n", $0}' "${BOSH_CA_CERT}")"

cat > integration-config.json <<EOF
{
  "bosh_host": "${BOSH_HOST}",
  "bosh_ssh_username": "jumpbox",
  "bosh_ssh_private_key": ${BOSH_SSH_KEY},
  "bosh_client": "${BOSH_CLIENT}",
  "bosh_client_secret": "${BOSH_CLIENT_SECRET}",
  "bosh_ca_cert": "${bosh_ca_cert_json_value}",
  "timeout_in_minutes": 30,
  "stemcell_src": "${STEMCELL_PATH}",
  "stemcell_os": "${STEMCELL_OS}",
  "include_deployment_testcase": true,
  "include_truncate_db_blobstore_testcase": true
}
EOF

export INTEGRATION_CONFIG_PATH="${PWD}/integration-config.json"

./bosh-disaster-recovery-acceptance-tests/scripts/_run_acceptance_tests.sh
