#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

overridden_bosh_deployment="${REPO_PARENT}/bosh-deployment"
if [[ -e "${overridden_bosh_deployment}/bosh.yml" ]];then
  BOSH_DEPLOYMENT_PATH=${overridden_bosh_deployment}
else
  BOSH_DEPLOYMENT_PATH="/usr/local/bosh-deployment"
fi
export BOSH_DEPLOYMENT_PATH

[ -f /tmp/local-bosh/director/env ] || source "${REPO_ROOT}/ci/dockerfiles/docker-cpi/start-bosh.sh"
source /tmp/local-bosh/director/env

export OUTER_BOSH_ENV_PATH="/tmp/local-bosh/director/env"

bosh -n update-cloud-config \
  "${BOSH_DEPLOYMENT_PATH}/docker/cloud-config.yml" \
  -o "${REPO_ROOT}/ci/dockerfiles/docker-cpi/outer-cloud-config-ops.yml" \
  -v network=director_network

bosh int /tmp/local-bosh/director/creds.yml --path /jumpbox_ssh/private_key > /tmp/jumpbox_ssh_key.pem
chmod 400 /tmp/jumpbox_ssh_key.pem

DOCKER_CERTS="$(bosh int /tmp/local-bosh/director/bosh-director.yml --path /instance_groups/0/properties/docker_cpi/docker/tls)"
export DOCKER_CERTS
DOCKER_HOST="$(bosh int /tmp/local-bosh/director/bosh-director.yml --path /instance_groups/name=bosh/properties/docker_cpi/docker/host)"
export DOCKER_HOST

BOSH_BINARY_PATH=$(which bosh)
export BOSH_BINARY_PATH
CANDIDATE_STEMCELL_TARBALL_PATH="$(find "${REPO_PARENT}/stemcell" -maxdepth 1 -path '*.tgz')"
export CANDIDATE_STEMCELL_TARBALL_PATH
export STEMCELL_OS=ubuntu-noble

bosh -n upload-stemcell "${CANDIDATE_STEMCELL_TARBALL_PATH}"

export BOSH_RELEASE="${REPO_ROOT}/src/spec/assets/dummy-release.tgz"
export BOSH_DIRECTOR_RELEASE_PATH="${REPO_PARENT}/bosh-release"
DNS_RELEASE_PATH="$(find "${REPO_PARENT}/bosh-dns-release" -maxdepth 1 -path '*.tgz')"
export DNS_RELEASE_PATH
export BOSH_DNS_ADDON_OPS_FILE_PATH="${BOSH_DEPLOYMENT_PATH}/misc/dns-addon.yml"

apt-get update
apt-get install -y mysql-client postgresql-client

if [ -d database-metadata ]; then
  RDS_MYSQL_EXTERNAL_DB_HOST="$(jq -r .aws_mysql_endpoint database-metadata/metadata | cut -d':' -f1)"
  export RDS_MYSQL_EXTERNAL_DB_HOST
  RDS_POSTGRES_EXTERNAL_DB_HOST="$(jq -r .aws_postgres_endpoint database-metadata/metadata | cut -d':' -f1)"
  export RDS_POSTGRES_EXTERNAL_DB_HOST
  GCP_MYSQL_EXTERNAL_DB_HOST="$(jq -r .gcp_mysql_endpoint database-metadata/metadata)"
  export GCP_MYSQL_EXTERNAL_DB_HOST
  GCP_POSTGRES_EXTERNAL_DB_HOST="$(jq -r .gcp_postgres_endpoint database-metadata/metadata)"
  export GCP_POSTGRES_EXTERNAL_DB_HOST
  GCP_MYSQL_EXTERNAL_DB_CA="$(jq -r .gcp_mysql_ca database-metadata/metadata)"
  export GCP_MYSQL_EXTERNAL_DB_CA
  GCP_MYSQL_EXTERNAL_DB_CLIENT_CERTIFICATE="$(jq -r .gcp_mysql_client_cert database-metadata/metadata)"
  export GCP_MYSQL_EXTERNAL_DB_CLIENT_CERTIFICATE
  GCP_MYSQL_EXTERNAL_DB_CLIENT_PRIVATE_KEY="$(jq -r .gcp_mysql_client_key database-metadata/metadata)"
  export GCP_MYSQL_EXTERNAL_DB_CLIENT_PRIVATE_KEY
  GCP_POSTGRES_EXTERNAL_DB_CA="$(jq -r .gcp_postgres_ca database-metadata/metadata)"
  export GCP_POSTGRES_EXTERNAL_DB_CA
  GCP_POSTGRES_EXTERNAL_DB_CLIENT_CERTIFICATE="$(jq -r .gcp_postgres_client_cert database-metadata/metadata)"
  export GCP_POSTGRES_EXTERNAL_DB_CLIENT_CERTIFICATE
  GCP_POSTGRES_EXTERNAL_DB_CLIENT_PRIVATE_KEY="$(jq -r .gcp_postgres_client_key database-metadata/metadata)"
  export GCP_POSTGRES_EXTERNAL_DB_CLIENT_PRIVATE_KEY
fi

brats_env_file="${REPO_PARENT}/brats-env.sh"
{
  echo "export OUTER_BOSH_ENV_PATH=\"${OUTER_BOSH_ENV_PATH}\""
  echo "export DOCKER_CERTS=\"${DOCKER_CERTS}\""
  echo "export DOCKER_HOST=\"${DOCKER_HOST}\""

  echo "export BOSH_BINARY_PATH=\"${BOSH_BINARY_PATH}\""

  echo "export BOSH_DIRECTOR_IP=\"${BOSH_DIRECTOR_IP}\""

  echo "export BOSH_DEPLOYMENT_PATH=\"${BOSH_DEPLOYMENT_PATH}\""
  echo "export BOSH_RELEASE=\"${BOSH_RELEASE}\""
  echo "export BOSH_DIRECTOR_RELEASE_PATH=\"${BOSH_DIRECTOR_RELEASE_PATH}\""
  echo "export DNS_RELEASE_PATH=\"${DNS_RELEASE_PATH}\""
  echo "export CANDIDATE_STEMCELL_TARBALL_PATH=\"${CANDIDATE_STEMCELL_TARBALL_PATH}\""

  echo "export BOSH_DNS_ADDON_OPS_FILE_PATH=\"${BOSH_DNS_ADDON_OPS_FILE_PATH}\""

  echo "export RDS_MYSQL_EXTERNAL_DB_HOST=\"${RDS_MYSQL_EXTERNAL_DB_HOST:-}\""

  echo "export RDS_POSTGRES_EXTERNAL_DB_HOST=\"${RDS_POSTGRES_EXTERNAL_DB_HOST:-}\""

  echo "export GCP_MYSQL_EXTERNAL_DB_HOST=\"${GCP_MYSQL_EXTERNAL_DB_HOST:-}\""
  echo "export GCP_MYSQL_EXTERNAL_DB_CA=\"${GCP_MYSQL_EXTERNAL_DB_CA:-}\""
  echo "export GCP_MYSQL_EXTERNAL_DB_CLIENT_CERTIFICATE=\"${GCP_MYSQL_EXTERNAL_DB_CLIENT_CERTIFICATE:-}\""
  echo "export GCP_MYSQL_EXTERNAL_DB_CLIENT_PRIVATE_KEY=\"${GCP_MYSQL_EXTERNAL_DB_CLIENT_PRIVATE_KEY:-}\""

  echo "export GCP_POSTGRES_EXTERNAL_DB_HOST=\"${GCP_POSTGRES_EXTERNAL_DB_HOST:-}\""
  echo "export GCP_POSTGRES_EXTERNAL_DB_CA=\"${GCP_POSTGRES_EXTERNAL_DB_CA:-}\""
  echo "export GCP_POSTGRES_EXTERNAL_DB_CLIENT_CERTIFICATE=\"${GCP_POSTGRES_EXTERNAL_DB_CLIENT_CERTIFICATE:-}\""
  echo "export GCP_POSTGRES_EXTERNAL_DB_CLIENT_PRIVATE_KEY=\"${GCP_POSTGRES_EXTERNAL_DB_CLIENT_PRIVATE_KEY:-}\""

  echo "# load outer-bosh env"
  echo "source "${OUTER_BOSH_ENV_PATH}
} > "${brats_env_file}"

echo "# The required BRATS environment can be loaded by running the following:"
echo "# 'source ${brats_env_file}'"

pushd "${REPO_ROOT}/src/brats/acceptance"
  go run github.com/onsi/ginkgo/v2/ginkgo \
    -r -v --race --timeout=24h \
    --randomize-suites --randomize-all \
    --focus="${FOCUS_SPEC:-}" \
    .
popd
