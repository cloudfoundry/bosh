#!/usr/bin/env bash

set -eu

function cleanup_mysql() {
  echo 'Cleanup MYSQL ============'
  hostname=$1
  username=$2
  export MYSQL_PWD=$3
  database_name=$4

  mysql -h ${hostname} -P 3306 --user=${username} -e "drop database ${database_name};"
  mysql -h ${hostname} -P 3306 --user=${username} -e "show databases;"
  mysql -h ${hostname} -P 3306 --user=${username} -e "create database ${database_name};"
  mysql -h ${hostname} -P 3306 --user=${username} -e "show databases;"
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
  createdb -U ${username} -p 5432 -h ${hostname} ${database_name}
  psql -h ${hostname} -p 5432 -U ${username} -c '\l' | grep ${database_name}
}

echo 'Cleanup RDS ============================'
cleanup_mysql $RDS_MYSQL_EXTERNAL_DB_HOST $RDS_MYSQL_EXTERNAL_DB_USER $RDS_MYSQL_EXTERNAL_DB_PASSWORD $RDS_MYSQL_EXTERNAL_DB_NAME
cleanup_postgres $RDS_POSTGRES_EXTERNAL_DB_HOST $RDS_POSTGRES_EXTERNAL_DB_USER $RDS_POSTGRES_EXTERNAL_DB_PASSWORD $RDS_POSTGRES_EXTERNAL_DB_NAME

echo 'Cleanup GCP ============================'
cleanup_mysql $GCP_MYSQL_EXTERNAL_DB_HOST $GCP_MYSQL_EXTERNAL_DB_USER $GCP_MYSQL_EXTERNAL_DB_PASSWORD $GCP_MYSQL_EXTERNAL_DB_NAME
cleanup_postgres $GCP_POSTGRES_EXTERNAL_DB_HOST $GCP_POSTGRES_EXTERNAL_DB_USER $GCP_POSTGRES_EXTERNAL_DB_PASSWORD $GCP_POSTGRES_EXTERNAL_DB_NAME

