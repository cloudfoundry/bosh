#!/bin/bash

set -e

function fromEnvironment() {
  local key="$1"
  local environment=environment/metadata
  cat $environment | jq -r "$key"
}

cat > bats.env <<EOF
export BOSH_ENVIRONMENT=$(fromEnvironment '.DirectorEIP')
export BOSH_CLIENT="admin"
export BOSH_CLIENT_SECRET="$(bosh-cli int director-state/director-creds.yml --path=/admin_password)"
export BOSH_CA_CERT="$(bosh-cli int director-state/director-creds.yml --path=/director_ssl/ca)"

export BOSH_GW_HOST=$(fromEnvironment '.DirectorEIP')
export BOSH_GW_USER="vcap"

export BAT_DNS_HOST=$(fromEnvironment '.DirectorEIP')
export BAT_PRIVATE_KEY="$(bosh-cli int director-state/director.yml --path=/cloud_provider/ssh_tunnel/private_key)"

export BAT_INFRASTRUCTURE=aws
export BAT_NETWORKING=manual

export BAT_RSPEC_FLAGS="--tag ~multiple_manual_networks --tag ~root_partition"
EOF

cat > bats-config.yml <<EOF
---
cpi: aws
properties:
  vip: $(fromEnvironment '.DeploymentEIP')
  second_static_ip: $(fromEnvironment '.StaticIP2')
  pool_size: 1
  stemcell:
    name: ${STEMCELL_NAME}
    version: latest
  instances: 1
  availability_zone: $(fromEnvironment '.AvailabilityZone')
  networks:
    - name: default
      static_ip: $(fromEnvironment '.StaticIP1')
      type: manual
      cidr: $(fromEnvironment '.PublicCIDR')
      reserved: [$(fromEnvironment '.ReservedRange')]
      static: [$(fromEnvironment '.StaticRange')]
      gateway: $(fromEnvironment '.PublicGateway')
      subnet: $(fromEnvironment '.PublicSubnetID')
      security_groups: [$(fromEnvironment '.SecurityGroupID')]
EOF

mv bats.env bats-config.yml bats-config/
