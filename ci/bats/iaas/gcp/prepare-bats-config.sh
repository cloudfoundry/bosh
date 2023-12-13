#!/bin/bash

set -e

TERRAFORM_OUTPUTS="${WORKSPACE_DIR}/terraform/metadata"

terraform_output(){
  output=$1
  jq -r ".${output}" "${TERRAFORM_OUTPUTS}"
}

manifest_path() { bosh int director-state/director.yml --path="$1" ; }
creds_path() { bosh int director-state/director-creds.yml --path="$1" ; }

director_ip=$( manifest_path "/instance_groups/0/networks/name=public/static_ips/0" )
gateway_username=$( manifest_path "/instance_groups/0/jobs/name=user_add/properties/users/0/name" )
ssh_private_key=$( creds_path /jumpbox_ssh/private_key | sed 's/$/\\n/' | tr -d '\n' )

cat > bats-config/bats.env <<EOF
export BOSH_ENVIRONMENT="$(terraform_output "director_public_ip")"
export BOSH_CLIENT="admin"
export BOSH_CLIENT_SECRET="$( creds_path /admin_password )"
export BOSH_CA_CERT="$( creds_path /director_ssl/ca )"

export BAT_INFRASTRUCTURE=gcp

private_key_path=\$(mktemp)
echo -e "${ssh_private_key}" > \${private_key_path}

export BOSH_ALL_PROXY="ssh+socks5://${gateway_username}@${director_ip}:22?private-key=\${private_key_path}"


#export BAT_RSPEC_FLAGS="--tag ~vip_networking --tag ~multiple_manual_networks --tag ~root_partition --tag ~raw_ephemeral_storage --tag ~skip_centos"
export BAT_RSPEC_FLAGS="--tag ~vip_networking --tag ~multiple_manual_networks --tag ~raw_ephemeral_storage"
EOF

cat > bats-config/bats-config.yml <<EOF
---
cpi: google
properties:
  availability_zone: "$(terraform_output "zone")"
  zone: "$(terraform_output "zone")"
  preemptible: true
  pool_size: 1
  instances: 1
  second_static_ip: "$(terraform_output "second_static_ip_first_network")"
  ssh_gateway:
    host: "${director_ip}"
    username: "${gateway_username}"
  ssh_key_pair:
    public_key: "$( creds_path /jumpbox_ssh/public_key )"
    private_key: "${ssh_private_key}"
  stemcell:
    name: "${STEMCELL_NAME}"
    version: latest
  networks:
    - name: default
      type: manual
      static_ip: "$(terraform_output "static_ip_first_network")" # Primary (private) IP assigned to the bat-release job vm (primary NIC), must be in the primary static range
      subnets:
      - range: "$(terraform_output "internal_cidr")"
        gateway: "$(terraform_output "gateway")"
        static: ["$(terraform_output "static_ip_first_network")", "$(terraform_output "second_static_ip_first_network")"]
        reserved: ["$(terraform_output "gateway")", "$(terraform_output "director_ip")"]
        cloud_properties:
          network_name: "$(terraform_output "network")"
          subnetwork_name: "$(terraform_output "subnetwork")"
          ephemeral_external_ip: false
          tags: ["bosh-director"]
        dns: [8.8.8.8]
    - name: second
      type: manual
      static_ip: "$(terraform_output "static_ip_second_network")"
      subnets:
      - range: "$(terraform_output "second_internal_cidr")"
        gateway: "$(terraform_output "second_gateway")"
        static: ["$(terraform_output "static_ip_second_network")"]
        reserved: ["$(terraform_output "second_gateway")"]
        cloud_properties:
          network_name: "$(terraform_output "network")"
          subnetwork_name: "$(terraform_output "second_subnetwork")"
          ephemeral_external_ip: false
          tags: ["bosh-director"]
        dns: [8.8.8.8]
EOF
