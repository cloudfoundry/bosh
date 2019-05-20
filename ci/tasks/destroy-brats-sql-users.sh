#!/bin/bash

set -eu
apt update && apt install jq -y

cred_file=$(mktemp)
echo "$GOOGLE_CREDENTIALS" > $cred_file

postgres_instance_name=$(jq -r .gcp_postgres_instance_name terraform-output/metadata )
mysql_instance_name=$(jq -r .gcp_mysql_instance_name terraform-output/metadata )

gcloud auth activate-service-account --key-file=$cred_file
gcloud config set project cf-bosh-core

gcloud sql users delete -q "${GCP_POSTGRES_USERNAME}" --instance "${postgres_instance_name}" --host ' '
gcloud sql users delete -q "${GCP_MYSQL_USERNAME}" --instance "${mysql_instance_name}" --host ' '
