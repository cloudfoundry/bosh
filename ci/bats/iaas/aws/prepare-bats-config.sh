#!/bin/bash

set -e

state_path() { bosh-cli int director-state/director.yml --path="$1" ; }
creds_path() { bosh-cli int director-state/director-creds.yml --path="$1" ; }

cat > bats-config/bats.env <<EOF
export BOSH_ENVIRONMENT="$( state_path /instance_groups/name=bosh/networks/name=public/static_ips/0 2>/dev/null )"
export BOSH_CLIENT="admin"
export BOSH_CLIENT_SECRET="$( creds_path /admin_password )"
export BOSH_CA_CERT="$( creds_path /director_ssl/ca )"
export BOSH_GW_HOST="$( state_path /instance_groups/name=bosh/networks/name=public/static_ips/0 2>/dev/null )"
export BOSH_GW_USER="jumpbox"
export BAT_PRIVATE_KEY="$( creds_path /jumpbox_ssh/private_key )"

export BAT_DNS_HOST="$( state_path /instance_groups/name=bosh/networks/name=public/static_ips/0 2>/dev/null )"

export BAT_INFRASTRUCTURE=aws
export BAT_NETWORKING=manual

export BAT_RSPEC_FLAGS="--tag ~multiple_manual_networks --tag ~root_partition"
EOF

cat > interpolate.yml <<EOF
---
cpi: aws
properties:
    vip: ((DeploymentEIP))
    second_static_ip: ((StaticIP2))
    pool_size: 1
    stemcell:
      name: ((STEMCELL_NAME))
      version: latest
    instances: 1
    availability_zone: ((AvailabilityZone))
    networks:
    - name: default
      static_ip: ((StaticIP1))
      type: manual
      cidr: ((PublicCIDR))
      reserved: [((ReservedRange))]
      static: [((StaticRange))]
      gateway: ((PublicGateway))
      subnet: ((PublicSubnetID))
      security_groups: ((SecurityGroupID))
EOF

bosh-cli interpolate \
 --vars-file environment/metadata \
 -v STEMCELL_NAME=$STEMCELL_NAME \
 interpolate.yml \
 > bats-config/bats-config.yml
