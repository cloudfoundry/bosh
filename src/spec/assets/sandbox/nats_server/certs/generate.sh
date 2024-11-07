#!/usr/bin/env bash

#HOSTNAME="$(hostname)"
HOSTNAME="localhost"
CREDS_FILE='./creds.yml'
TEMPLATE_FILE='./manifest.yml'

rm -rf ./creds.yml ./nats/ ./director/ ./health_monitor/ ./test_client

mkdir -p ./nats
mkdir -p ./director
mkdir -p ./health_monitor
mkdir -p ./test_client

bosh int --vars-store=${CREDS_FILE} -v hostname=$HOSTNAME ${TEMPLATE_FILE}

bosh int --path=/default_ca/ca ${CREDS_FILE} | sed '/^$/d' > rootCA.pem
bosh int --path=/default_ca/private_key ${CREDS_FILE} | sed '/^$/d' > rootCA.key

bosh int --path=/nats/certificate ${CREDS_FILE} | sed '/^$/d' > nats/certificate.pem
bosh int --path=/nats/private_key ${CREDS_FILE} | sed '/^$/d' > nats/private_key

bosh int --path=/director_client/certificate ${CREDS_FILE} | sed '/^$/d' > director/certificate.pem
bosh int --path=/director_client/private_key ${CREDS_FILE} | sed '/^$/d' > director/private_key

bosh int --path=/hm_client/certificate ${CREDS_FILE} | sed '/^$/d' > health_monitor/certificate.pem
bosh int --path=/hm_client/private_key ${CREDS_FILE} | sed '/^$/d' > health_monitor/private_key

# This cert can subscribe and publish to everything
bosh int --path=/test_client/certificate ${CREDS_FILE} | sed '/^$/d' > test_client/certificate.pem
bosh int --path=/test_client/private_key ${CREDS_FILE} | sed '/^$/d' > test_client/private_key

