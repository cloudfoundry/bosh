#!/bin/bash

set -eu

apt update && apt install jq -y

cred_file=$(mktemp)
echo "$GOOGLE_CREDENTIALS" > $cred_file
gcloud auth activate-service-account --key-file=$cred_file
gcloud config set project cf-bosh-core

mysql_instance_name=$(jq -r .gcp_mysql_instance_name terraform-output/metadata )
postgres_instance_name=$(jq -r .gcp_postgres_instance_name terraform-output/metadata )

mysql_ca_cert="$(gcloud beta sql ssl server-ca-certs list --format='value(cert)' --instance=$mysql_instance_name)"
postgres_ca_cert="$(gcloud beta sql ssl server-ca-certs list --format='value(cert)' --instance=$postgres_instance_name)"

if ! bash -c "gcloud sql ssl client-certs list --instance=$mysql_instance_name 2>&1 | grep  -q '0 items'"; then
  gcloud sql ssl client-certs delete brats-ssl --instance=$mysql_instance_name --quiet
fi
rm -f /tmp/mysql-client-key.pem
gcloud sql ssl client-certs create brats-ssl /tmp/mysql-client-key.pem --instance=$mysql_instance_name

if ! bash -c "gcloud sql ssl client-certs list --instance=$postgres_instance_name 2>&1 | grep  -q '0 items'"; then
  gcloud sql ssl client-certs delete brats-ssl --instance=$postgres_instance_name --quiet
fi
rm -f /tmp/postgres-client-key.pem
gcloud sql ssl client-certs create brats-ssl /tmp/postgres-client-key.pem --instance=$postgres_instance_name

mysql_client_cert="$(gcloud sql ssl client-certs describe brats-ssl --format='value(cert)' --instance=$mysql_instance_name)"
postgres_client_cert="$(gcloud sql ssl client-certs describe brats-ssl --format='value(cert)' --instance=$postgres_instance_name)"

mysql_client_key="$(cat /tmp/mysql-client-key.pem)"
postgres_client_key="$(cat /tmp/postgres-client-key.pem)"


echo "{}" | jq \
  --arg mysql_client_cert "$mysql_client_cert" \
  --arg mysql_client_key "$mysql_client_key" \
  --arg mysql_ca_cert "$mysql_ca_cert" \
  '{
    "mysql_client_cert": $mysql_client_cert,
    "mysql_client_key": $mysql_client_key,
    "mysql_ca_cert": $mysql_ca_cert,
   }' \
   > gcp-ssl-config/gcp_mysql.yml

echo "{}" | jq \
  --arg postgres_client_cert "$postgres_client_cert" \
  --arg postgres_client_key "$postgres_client_key" \
  --arg postgres_ca_cert "$postgres_ca_cert" \
  '{
    "postgres_client_cert": $postgres_client_cert,
    "postgres_client_key": $postgres_client_key,
    "postgres_ca_cert": $postgres_ca_cert,
   }' \
   > gcp-ssl-config/gcp_postgres.yml
