#!/usr/bin/env bash

set -e

: ${BOSH_VSPHERE_VCENTER:?}
: ${BOSH_VSPHERE_VCENTER_USER:?}
: ${BOSH_VSPHERE_VCENTER_PASSWORD:?}
: ${BOSH_VSPHERE_VCENTER_DC:?}
: ${BOSH_VSPHERE_VCENTER_CLUSTER:?}
: ${BOSH_VSPHERE_VCENTER_VM_FOLDER:?}
: ${BOSH_VSPHERE_VCENTER_TEMPLATE_FOLDER:?}
: ${BOSH_VSPHERE_VCENTER_DATASTORE:?}
: ${BOSH_VSPHERE_VCENTER_DISK_PATH:?}
: ${BOSH_VSPHERE_VCENTER_VLAN:?}
: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}

: ${DIRECTOR_IP:?}
: ${BOSH_VSPHERE_VCENTER_CIDR:?}
: ${BOSH_VSPHERE_VCENTER_GATEWAY:?}
: ${BOSH_VSPHERE_DNS:?}

source /etc/profile.d/chruby.sh
chruby 2.1.7

# inputs
# paths will be resolved in a separate task so use relative paths

BOSH_RELEASE_URI="file://../$(echo bosh-release/*.tgz)"
CPI_RELEASE_URI="file://../$(echo cpi-release/*.tgz)"
STEMCELL_URI="file://../$(echo stemcell/*.tgz)"
BOSH_CLI="$(pwd)/$(echo bosh-cli/bosh-cli-*)"
chmod +x ${BOSH_CLI}

# outputs
output_dir="$(pwd)/director-state"

cat > "${output_dir}/director.yml" <<EOF
---
name: stemcell-smoke-tests-director

releases:
  - name: bosh
    url: ${BOSH_RELEASE_URI}
  - name: bosh-vsphere-cpi
    url: ${CPI_RELEASE_URI}

resource_pools:
  - name: vms
    network: private
    stemcell:
      url: ${STEMCELL_URI}
    cloud_properties:
      cpu: 2
      ram: 4_096
      disk: 20_000

disk_pools:
  - name: disks
    disk_size: 20_000

networks:
  - name: private
    type: manual
    subnets:
      - range: ${BOSH_VSPHERE_VCENTER_CIDR}
        gateway: ${BOSH_VSPHERE_VCENTER_GATEWAY}
        dns: [${BOSH_VSPHERE_DNS}]
        cloud_properties: {name: ${BOSH_VSPHERE_VCENTER_VLAN}}

jobs:
  - name: bosh
    instances: 1

    templates:
      - {name: nats, release: bosh}
      - {name: postgres, release: bosh}
      - {name: blobstore, release: bosh}
      - {name: director, release: bosh}
      - {name: health_monitor, release: bosh}
      - {name: powerdns, release: bosh}
      - {name: vsphere_cpi, release: bosh-vsphere-cpi}

    resource_pool: vms
    persistent_disk_pool: disks

    networks:
      - {name: private, static_ips: [${DIRECTOR_IP}]}

    properties:
      nats:
        address: 127.0.0.1
        user: nats
        password: nats-password

      postgres: &db
        host: 127.0.0.1
        user: postgres
        password: postgres-password
        database: bosh
        adapter: postgres

      blobstore:
        address: ${DIRECTOR_IP}
        port: 25250
        provider: dav
        director: {user: director, password: director-password}
        agent: {user: agent, password: agent-password}

      director:
        address: 127.0.0.1
        name: stemcell-smoke-tests-director
        db: *db
        cpi_job: vsphere_cpi
        user_management:
          provider: local
          local:
            users:
              - {name: ${BOSH_DIRECTOR_USERNAME}, password: ${BOSH_DIRECTOR_PASSWORD}}

      hm:
        http: {user: hm, password: hm-password}
        director_account: {user: ${BOSH_DIRECTOR_USERNAME}, password: ${BOSH_DIRECTOR_PASSWORD}}
        resurrector_enabled: true

      agent: {mbus: "nats://nats:nats-password@${DIRECTOR_IP}:4222"}

      dns:
        address: 127.0.0.1
        db: *db

      vcenter: &vcenter
        address: ${BOSH_VSPHERE_VCENTER}
        user: ${BOSH_VSPHERE_VCENTER_USER}
        password: ${BOSH_VSPHERE_VCENTER_PASSWORD}
        datacenters:
          - name: ${BOSH_VSPHERE_VCENTER_DC}
            vm_folder: ${BOSH_VSPHERE_VCENTER_VM_FOLDER}
            template_folder: ${BOSH_VSPHERE_VCENTER_TEMPLATE_FOLDER}
            datastore_pattern: ${BOSH_VSPHERE_VCENTER_DATASTORE}
            persistent_datastore_pattern: ${BOSH_VSPHERE_VCENTER_DATASTORE}
            disk_path: ${BOSH_VSPHERE_VCENTER_DISK_PATH}
            clusters: [${BOSH_VSPHERE_VCENTER_CLUSTER}]

cloud_provider:
  template: {name: vsphere_cpi, release: bosh-vsphere-cpi}

  mbus: "https://mbus:mbus-password@${DIRECTOR_IP}:6868"

  properties:
    vcenter: *vcenter
    agent: {mbus: "https://mbus:mbus-password@0.0.0.0:6868"}
    blobstore: {provider: local, path: /var/vcap/micro_bosh/data/cache}
    ntp: [0.pool.ntp.org, 1.pool.ntp.org]
EOF

echo "deploying BOSH..."

pushd ${output_dir}
  set +e
  logfile=$(mktemp)
  BOSH_LOG_PATH=$logfile ${BOSH_CLI} create-env director.yml
  bosh_cli_exit_code="$?"
  set -e
popd

if [ ${bosh_cli_exit_code} != 0 ]; then
  echo "bosh-cli deploy failed!" >&2
  cat $logfile >&2
  exit ${bosh_cli_exit_code}
fi
