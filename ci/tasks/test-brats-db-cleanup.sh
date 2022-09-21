#!/usr/bin/env bash

set -eu

function cleanup_mysql() {
  echo 'Cleanup MYSQL ============'
  hostname=$1
  username=$2
  export MYSQL_PWD=$3
  database_name=$4

  mysql -h ${hostname} -P 3306 --user=${username} -e "drop database ${database_name};" || true
}

function cleanup_postgres() {
  echo 'Cleanup POSTGRES ============'
  hostname=$1
  username=$2
  export PGPASSWORD=$3
  database_name=$4

  # Assumption: we are deleting inner-bosh in AfterEach so all connection will be terminated,
  #             so we dont need to revoke connection
  dropdb -U ${username} -p 5432 -h ${hostname} ${database_name} || true
}

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

echo 'Cleanup RDS ============================'
cleanup_mysql $RDS_MYSQL_EXTERNAL_DB_HOST $RDS_MYSQL_EXTERNAL_DB_USER $RDS_MYSQL_EXTERNAL_DB_PASSWORD $RDS_MYSQL_EXTERNAL_DB_NAME
cleanup_postgres $RDS_POSTGRES_EXTERNAL_DB_HOST $RDS_POSTGRES_EXTERNAL_DB_USER $RDS_POSTGRES_EXTERNAL_DB_PASSWORD $RDS_POSTGRES_EXTERNAL_DB_NAME

echo 'Cleanup GCP ============================'
cleanup_mysql $GCP_MYSQL_EXTERNAL_DB_HOST $GCP_MYSQL_EXTERNAL_DB_USER $GCP_MYSQL_EXTERNAL_DB_PASSWORD $GCP_MYSQL_EXTERNAL_DB_NAME
cleanup_postgres $GCP_POSTGRES_EXTERNAL_DB_HOST $GCP_POSTGRES_EXTERNAL_DB_USER $GCP_POSTGRES_EXTERNAL_DB_PASSWORD $GCP_POSTGRES_EXTERNAL_DB_NAME

