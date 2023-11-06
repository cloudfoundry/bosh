#!/bin/bash

set -e

manifest_path() { bosh int director-state/director.yml --path="$1" ; }
creds_path() { bosh int director-state/director-creds.yml --path="$1" ; }

cat > bats-config/bats.env <<EOF
export BOSH_ENVIRONMENT="$( manifest_path /instance_groups/name=bosh/networks/name=default/static_ips/0 2>/dev/null )"
export BOSH_CLIENT="admin"
export BOSH_CLIENT_SECRET="$( creds_path /admin_password )"
export BOSH_CA_CERT="$( creds_path /director_ssl/ca )"
export BOSH_GW_HOST="$( manifest_path /instance_groups/name=bosh/networks/name=default/static_ips/0 2>/dev/null )"
export BOSH_GW_USER="jumpbox"
export BAT_PRIVATE_KEY="$( creds_path /jumpbox_ssh/private_key )"

export BAT_DNS_HOST="$( manifest_path /instance_groups/name=bosh/networks/name=default/static_ips/0 2>/dev/null )"

export BAT_INFRASTRUCTURE=gcp
export BAT_NETWORKING=manual

export BAT_RSPEC_FLAGS="--tag ~vip_networking --tag ~multiple_manual_networks --tag ~root_partition --tag ~raw_ephemeral_storage --tag ~skip_centos"
EOF

cat > interpolate.yml <<EOF
---
cpi: google
properties:
  availability_zone: ((AVAILABILITY_ZONE))
  zone: ((ZONE))
  preemptible: ((PREEMPTIBLE))
  pool_size: 1
  instances: 1
  second_static_ip: ((STATIC_IP_DEFAULT-2))
  stemcell:
    name: ((STEMCELL_NAME))
    version: latest
  networks:
    - name: default
      type: manual
      static_ip: ((STATIC_IP_DEFAULT)) # Primary (private) IP assigned to the bat-release job vm (primary NIC), must be in the primary static range
      subnets:
      - range: ((CIDR_DEFAULT))
        static: ((STATIC_DEFAULT))
        gateway: ((GATEWAY_DEFAULT))
        cloud_properties:
          network_name: ((NETWORK_DEFAULT))
          subnetwork_name: ((SUBNETWORK_DEFAULT))
          ephemeral_external_ip: false
        dns: [8.8.8.8]
EOF

bosh interpolate \
 --vars-env VARS \
 interpolate.yml \
 > bats-config/bats-config.yml
