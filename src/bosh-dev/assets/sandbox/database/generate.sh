#!/usr/bin/env bash

#HOSTNAME="$(hostname)"
HOSTNAME="127.0.0.1"
CREDS_FILE='./creds.yml'
TEMPLATE_FILE='./manifest.yml'

rm -rf ./creds.yml ./nats/ ./director/ ./health_monitor/ ./test_client

gobosh int --vars-store=${CREDS_FILE} -v hostname=$HOSTNAME ${TEMPLATE_FILE}

mkdir -p postgres_server
mkdir -p postgres_client

gobosh int --path=/default_ca/ca ${CREDS_FILE} | sed '/^$/d' > rootCA.pem
gobosh int --path=/default_ca/private_key ${CREDS_FILE} | sed '/^$/d' > rootCA.key

gobosh int --path=/postgres_server/certificate ${CREDS_FILE} | sed '/^$/d' > postgres_server/certificate.pem
gobosh int --path=/postgres_server/private_key ${CREDS_FILE} | sed '/^$/d' > postgres_server/private_key

gobosh int --path=/postgres_client/certificate ${CREDS_FILE} | sed '/^$/d' > postgres_client/certificate.pem
gobosh int --path=/postgres_client/private_key ${CREDS_FILE} | sed '/^$/d' > postgres_client/private_key

chmod 600 postgres_server/certificate.pem
chmod 600 postgres_server/private_key

chmod 600 postgres_client/certificate.pem
chmod 600 postgres_client/private_key