#!/usr/bin/env bash

set -ex

#HOSTNAME="$(hostname)"
HOSTNAME="127.0.0.1"
CREDS_FILE='./creds.yml'
TEMPLATE_FILE='./manifest.yml'

rm -rf ./creds.yml ./nats/ ./director/ ./health_monitor/ ./test_client

bosh int --vars-store=${CREDS_FILE} -v hostname=$HOSTNAME ${TEMPLATE_FILE}

mkdir -p database_server
mkdir -p database_client

bosh int --path=/default_ca/ca ${CREDS_FILE} | sed '/^$/d' > rootCA.pem
bosh int --path=/default_ca/private_key ${CREDS_FILE} | sed '/^$/d' > rootCA.key
bosh int --path=/database_server/certificate ${CREDS_FILE} | sed '/^$/d' > database_server/certificate.pem
bosh int --path=/database_server/private_key ${CREDS_FILE} | sed '/^$/d' > database_server/private_key
bosh int --path=/database_client/certificate ${CREDS_FILE} | sed '/^$/d' > database_client/certificate.pem
bosh int --path=/database_client/private_key ${CREDS_FILE} | sed '/^$/d' > database_client/private_key
chmod 600 database_server/certificate.pem
chmod 600 database_server/private_key

chmod 600 database_client/certificate.pem
chmod 600 database_client/private_key