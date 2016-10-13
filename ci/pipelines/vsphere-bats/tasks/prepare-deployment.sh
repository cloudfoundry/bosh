#!/usr/bin/env bash

set -e

: ${BOSH_DIRECTOR_PASSWORD:?}
: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_VSPHERE_VCENTER_VLAN:?}
: ${RELEASE_NAME:?}
: ${STEMCELL_NAME:?}
: ${DEPLOYMENT_NAME:?}

source pipelines/shared/utils.sh

# inputs
bosh_cli=$(realpath bosh-cli/bosh-cli-*)
chmod +x $bosh_cli

# outputs
manifest_dir="$(realpath deployment-manifest)"

env_name=$(cat environment/name)
metadata=$(cat environment/metadata)
network1=$(env_attr "${metadata}" "network1")
echo Using environment: \'${env_name}\'

: ${DIRECTOR_IP:=$(                  env_attr "${metadata}" "directorIP" )}
: ${BOSH_VSPHERE_VCENTER_CIDR:=$(    env_attr "${network1}" "vCenterCIDR" )}
: ${BOSH_VSPHERE_VCENTER_GATEWAY:=$( env_attr "${network1}" "vCenterGateway" )}
: ${BOSH_VSPHERE_DNS:=$(             env_attr "${metadata}" "DNS" )}
: ${STATIC_IP:=$(                    env_attr "${network1}" "staticIP-1" )}
: ${RESERVED_RANGE:=$(               env_attr "${network1}" "reservedRange" )}
: ${STATIC_RANGE:=$(                 env_attr "${network1}" "staticRange" )}

time $bosh_cli -n env ${DIRECTOR_IP//./-}.sslip.io
time $bosh_cli -n login --user=${BOSH_DIRECTOR_USERNAME} --password=${BOSH_DIRECTOR_PASSWORD}

cat > "${manifest_dir}/deployment.yml" <<EOF
---
name: ${DEPLOYMENT_NAME}

releases:
  - name: ${RELEASE_NAME}
    version: latest

compilation:
  reuse_compilation_vms: true
  workers: 1
  network: private
  cloud_properties:
    cpu: 2
    ram: 1024
    disk: 10240

update:
  canaries: 1
  canary_watch_time: 30000-240000
  update_watch_time: 30000-600000
  max_in_flight: 3

resource_pools:
  - name: default
    stemcell:
      name: ${STEMCELL_NAME}
      version: latest
    network: private
    cloud_properties:
      cpu: 2
      ram: 1024
      disk: 10240

networks:
  - name: private
    type: manual
    subnets:
      - range: ${BOSH_VSPHERE_VCENTER_CIDR}
        gateway: ${BOSH_VSPHERE_VCENTER_GATEWAY}
        dns: [${BOSH_VSPHERE_DNS}]
        cloud_properties: {name: ${BOSH_VSPHERE_VCENTER_VLAN}}
        reserved: [${RESERVED_RANGE}]
        static: [${STATIC_RANGE}]

jobs:
  - name: simple
    template: simple
    instances: 1
    resource_pool: default
    networks:
      - name: private
        default: [dns, gateway]
        static_ips: [${STATIC_IP}]
EOF
