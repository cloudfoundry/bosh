#!/usr/bin/env bash

set -eu

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
src_dir="${script_dir}/../../.."

export OVERRIDDEN_BOSH_DEPLOYMENT=$(realpath "$(dirname $0)/../../../bosh-deployment")
if [[ -e ${OVERRIDDEN_BOSH_DEPLOYMENT}/bosh.yml ]];then
  export BOSH_DEPLOYMENT_PATH=${OVERRIDDEN_BOSH_DEPLOYMENT}
else
  export BOSH_DEPLOYMENT_PATH="/usr/local/bosh-deployment"
fi

. start-bosh

source /tmp/local-bosh/director/env

. /tmp/local-bosh/director/env

export BOSH_DIRECTOR_IP="${BOSH_ENVIRONMENT}"

BOSH_BINARY_PATH=$(which bosh)
export BOSH_BINARY_PATH
export BOSH_RELEASE="${PWD}/bosh-src/src/spec/assets/dummy-release.tgz"
export BOSH_DIRECTOR_RELEASE_PATH="${PWD}/bosh-release"
DNS_RELEASE_PATH="$(realpath "$(find "${PWD}"/bosh-dns-release -maxdepth 1 -path '*.tgz')")"
export DNS_RELEASE_PATH
CANDIDATE_STEMCELL_TARBALL_PATH="$(realpath "${src_dir}"/stemcell/*.tgz)"
export CANDIDATE_STEMCELL_TARBALL_PATH
export BOSH_DNS_ADDON_OPS_FILE_PATH="${BOSH_DEPLOYMENT_PATH}/misc/dns-addon.yml"

export OUTER_BOSH_ENV_PATH="/tmp/local-bosh/director/env"

bosh -n update-cloud-config \
  ${src_dir}/bosh-src/ci/dockerfiles/warden-cpi/warden-cloud-config.yml

bosh -n upload-stemcell $CANDIDATE_STEMCELL_TARBALL_PATH

apt-get update
apt-get install -y mysql-client postgresql-client

if [ -d database-metadata ]; then
  RDS_MYSQL_EXTERNAL_DB_HOST="$(jq -r .aws_mysql_endpoint database-metadata/metadata | cut -d':' -f1)"
  RDS_POSTGRES_EXTERNAL_DB_HOST="$(jq -r .aws_postgres_endpoint database-metadata/metadata | cut -d':' -f1)"
  GCP_MYSQL_EXTERNAL_DB_HOST="$(jq -r .gcp_mysql_endpoint database-metadata/metadata)"
  GCP_POSTGRES_EXTERNAL_DB_HOST="$(jq -r .gcp_postgres_endpoint database-metadata/metadata)"
  GCP_MYSQL_EXTERNAL_DB_CA="$(jq -r .mysql_ca_cert gcp-ssl-config/gcp_mysql.yml)"
  GCP_MYSQL_EXTERNAL_DB_CLIENT_CERTIFICATE="$(jq -r .mysql_client_cert gcp-ssl-config/gcp_mysql.yml)"
  GCP_MYSQL_EXTERNAL_DB_CLIENT_PRIVATE_KEY="$(jq -r .mysql_client_key gcp-ssl-config/gcp_mysql.yml)"
  GCP_POSTGRES_EXTERNAL_DB_CA="$(jq -r .postgres_ca_cert gcp-ssl-config/gcp_postgres.yml)"
  GCP_POSTGRES_EXTERNAL_DB_CLIENT_CERTIFICATE="$(jq -r .postgres_client_cert gcp-ssl-config/gcp_postgres.yml)"
  GCP_POSTGRES_EXTERNAL_DB_CLIENT_PRIVATE_KEY="$(jq -r .postgres_client_key gcp-ssl-config/gcp_postgres.yml)"

  export RDS_MYSQL_EXTERNAL_DB_HOST
  export RDS_POSTGRES_EXTERNAL_DB_HOST
  export GCP_MYSQL_EXTERNAL_DB_HOST
  export GCP_POSTGRES_EXTERNAL_DB_HOST
  export GCP_MYSQL_EXTERNAL_DB_CA
  export GCP_MYSQL_EXTERNAL_DB_CLIENT_CERTIFICATE
  export GCP_MYSQL_EXTERNAL_DB_CLIENT_PRIVATE_KEY
  export GCP_POSTGRES_EXTERNAL_DB_CA
  export GCP_POSTGRES_EXTERNAL_DB_CLIENT_CERTIFICATE
  export GCP_POSTGRES_EXTERNAL_DB_CLIENT_PRIVATE_KEY
fi

pushd bosh-src > /dev/null
  scripts/test-brats
popd > /dev/null
