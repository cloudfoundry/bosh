#!/bin/bash

set -eu
apt update && apt install jq -y

cred_file=$(mktemp)
echo "$GOOGLE_CREDENTIALS" > $cred_file

postgres_instance_name=$(jq -r .gcp_postgres_instance_name terraform-output/metadata )
mysql_instance_name=$(jq -r .gcp_mysql_instance_name terraform-output/metadata )

gcloud auth activate-service-account --key-file=$cred_file
gcloud config set project cf-bosh-core

gcloud sql users create "${GCP_POSTGRES_USERNAME}" --password "${GCP_POSTGRES_PASSWORD}" --instance "${postgres_instance_name}"
gcloud sql users create "${GCP_MYSQL_USERNAME}" --password "${GCP_MYSQL_PASSWORD}" --instance "${mysql_instance_name}"
