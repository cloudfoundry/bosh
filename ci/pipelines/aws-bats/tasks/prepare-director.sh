#!/usr/bin/env bash

set -e

# inputs
workspace_dir="$( cd $(dirname $0) && cd ../../../../.. && pwd )"
ci_bosh_dir="${workspace_dir}/bosh-release"
ci_cpi_dir="${workspace_dir}/cpi-release"
ci_stemcell_dir="${workspace_dir}/stemcell"
ci_environment_dir="${workspace_dir}/environment"

# outputs
ci_output_dir="${workspace_dir}/director-config"

# environment
: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}
: ${AWS_ACCESS_KEY:?}
: ${AWS_SECRET_KEY:?}
: ${AWS_REGION_NAME:?}
: ${PUBLIC_KEY_NAME:?}
: ${PRIVATE_KEY_DATA:?}
: ${USE_REDIS:=false}
: ${BOSH_RELEASE_PATH:=}
: ${CPI_RELEASE_PATH:=}
: ${STEMCELL_PATH:=}
: ${METADATA_FILE:=${ci_environment_dir}/metadata}
: ${OUTPUT_DIR:=${ci_output_dir}}
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
nc='\033[0m'

if [ ! -d ${OUTPUT_DIR} ]; then
  echo -e "${red}OUTPUT_DIR '${OUTPUT_DIR}' does not exist${nc}"
  exit 1
fi
if [ ! -f ${METADATA_FILE} ]; then
  echo -e "${red}METADATA_FILE '${METADATA_FILE}' does not exist${nc}"
  exit 1
fi

metadata="$( cat ${METADATA_FILE} )"

tmpdir="$(mktemp -d /tmp/bosh-director-artifacts.XXXXXXXXXX)"

if [ -z "$BOSH_RELEASE_PATH" ]; then
  if [ -f ${ci_bosh_dir}/*.tgz ]; then
    BOSH_RELEASE_PATH="$( ls ${ci_bosh_dir}/*.tgz )"
    echo -e "${yellow}Using local bosh-release from ${BOSH_RELEASE_PATH}${nc}"
  else
    download_url="https://bosh.io/d/github.com/cloudfoundry/bosh"
    echo -e "${yellow}Downloading remote bosh-release from ${download_url}${nc}"
    BOSH_RELEASE_PATH="${tmpdir}/bosh.tgz"
    wget -O "${BOSH_RELEASE_PATH}" "${download_url}"
  fi
fi
# use relative paths: paths will be resolved in a separate task
bosh_release_uri="file://${BOSH_RELEASE_PATH/*bosh-release/bosh-release}"

if [ -z "$CPI_RELEASE_PATH" ]; then
  if [ -f ${ci_cpi_dir}/*.tgz ]; then
    CPI_RELEASE_PATH="$( ls ${ci_cpi_dir}/*.tgz )"
    echo -e "${yellow}Using local cpi-release from ${CPI_RELEASE_PATH}${nc}"
  else
    download_url="https://bosh.io/d/github.com/cloudfoundry-incubator/bosh-aws-cpi-release"
    echo -e "${yellow}Downloading remote cpi-release from ${download_url}${nc}"
    CPI_RELEASE_PATH="${tmpdir}/bosh-cpi.tgz"
    wget -O "${CPI_RELEASE_PATH}" "${download_url}"
  fi
fi
cpi_release_uri="file://${CPI_RELEASE_PATH/*cpi-release/cpi-release}"

if [ -z "$STEMCELL_PATH" ]; then
  if [ -f ${ci_stemcell_dir}/*.tgz ]; then
    STEMCELL_PATH="$( ls ${ci_stemcell_dir}/*.tgz )"
    echo -e "${yellow}Using local stemcell from ${STEMCELL_PATH}${nc}"
  else
    download_url="https://bosh.io/d/stemcells/bosh-aws-xen-hvm-ubuntu-trusty-go_agent"
    echo -e "${yellow}Downloading remote stemcell from ${download_url}${nc}"
    STEMCELL_PATH="${tmpdir}/stemcell.tgz"
    wget -O "${STEMCELL_PATH}" "${download_url}"
  fi
fi
stemcell_uri="file://${STEMCELL_PATH/*stemcell\//stemcell/}"

# configuration
: ${SECURITY_GROUP:=$(       echo ${metadata} | jq --raw-output ".SecurityGroupID" )}
: ${DIRECTOR_EIP:=$(         echo ${metadata} | jq --raw-output ".DirectorEIP" )}
: ${SUBNET_ID:=$(            echo ${metadata} | jq --raw-output ".PublicSubnetID" )}
: ${AVAILABILITY_ZONE:=$(    echo ${metadata} | jq --raw-output ".AvailabilityZone" )}
: ${AWS_NETWORK_CIDR:=$(     echo ${metadata} | jq --raw-output ".PublicCIDR" )}
: ${AWS_NETWORK_GATEWAY:=$(  echo ${metadata} | jq --raw-output ".PublicGateway" )}
: ${AWS_NETWORK_DNS:=$(      echo ${metadata} | jq --raw-output ".DNS" )}
: ${DIRECTOR_STATIC_IP:=$(   echo ${metadata} | jq --raw-output ".DirectorStaticIP" )}
: ${BLOBSTORE_BUCKET_NAME:=$(echo ${metadata} | jq --raw-output ".BlobstoreBucket" )}
: ${STATIC_RANGE:=$(         echo ${metadata} | jq --raw-output ".StaticRange" )}
: ${RESERVED_RANGE:=$(       echo ${metadata} | jq --raw-output ".ReservedRange" )}

# keys
shared_key="shared.pem"
echo "${PRIVATE_KEY_DATA}" > "${OUTPUT_DIR}/${shared_key}"

redis_job=""
if [ "${USE_REDIS}" == true ]; then
  redis_job="- {name: redis, release: bosh}"
fi

# env file generation
cat > "${OUTPUT_DIR}/director.env" <<EOF
#!/usr/bin/env bash

export BOSH_DIRECTOR_IP=${DIRECTOR_EIP}
export BOSH_DIRECTOR_USERNAME=${BOSH_DIRECTOR_USERNAME}
export BOSH_DIRECTOR_PASSWORD=${BOSH_DIRECTOR_PASSWORD}
EOF

# manifest generation
cat > "${OUTPUT_DIR}/director.yml" <<EOF
---
name: certification-director

releases:
  - name: bosh
    url: ${bosh_release_uri}
  - name: bosh-aws-cpi
    url: ${cpi_release_uri}

resource_pools:
  - name: default
    network: private
    stemcell:
      url: ${stemcell_uri}
    cloud_properties:
      instance_type: m3.medium
      availability_zone: ${AVAILABILITY_ZONE}
      ephemeral_disk:
        size: 25000

disk_pools:
  - name: default
    disk_size: 25_000
    cloud_properties: {}

networks:
  - name: private
    type: manual
    subnets:
    - range:    ${AWS_NETWORK_CIDR}
      gateway:  ${AWS_NETWORK_GATEWAY}
      dns:      [8.8.8.8]
      cloud_properties: {subnet: ${SUBNET_ID}}
  - name: public
    type: vip

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
      - {name: registry, release: bosh}
      - {name: aws_cpi, release: bosh-aws-cpi}
      ${redis_job}

    resource_pool: default
    persistent_disk_pool: default

    networks:
      - name: private
        static_ips: [${DIRECTOR_STATIC_IP}]
        default: [dns, gateway]
      - name: public
        static_ips: [${DIRECTOR_EIP}]

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

      # required for some upgrade paths
      redis:
        listen_addresss: 127.0.0.1
        address: 127.0.0.1
        password: redis-password

      registry:
        address: ${DIRECTOR_STATIC_IP}
        host: ${DIRECTOR_STATIC_IP}
        db: *db
        http: {user: ${BOSH_DIRECTOR_USERNAME}, password: ${BOSH_DIRECTOR_PASSWORD}, port: 25777}
        username: ${BOSH_DIRECTOR_USERNAME}
        password: ${BOSH_DIRECTOR_PASSWORD}
        port: 25777

      blobstore:
        director: {user: director, password: director-password}
        agent: {user: agent, password: agent-password}
        provider: s3
        s3_region: ${AWS_REGION_NAME}
        bucket_name: ${BLOBSTORE_BUCKET_NAME}
        s3_signature_version: '4'
        access_key_id: ${AWS_ACCESS_KEY}
        secret_access_key: ${AWS_SECRET_KEY}

      director:
        address: 127.0.0.1
        name: bats-director
        db: *db
        cpi_job: aws_cpi
        user_management:
          provider: local
          local:
            users:
              - {name: ${BOSH_DIRECTOR_USERNAME}, password: ${BOSH_DIRECTOR_PASSWORD}}

      hm:
        http: {user: hm, password: hm-password}
        director_account: {user: ${BOSH_DIRECTOR_USERNAME}, password: ${BOSH_DIRECTOR_PASSWORD}}

      dns:
        recursor: 10.0.0.2
        address: 127.0.0.1
        db: *db

      agent: {mbus: "nats://nats:nats-password@${DIRECTOR_STATIC_IP}:4222"}

      ntp: &ntp
        - 0.north-america.pool.ntp.org
        - 1.north-america.pool.ntp.org

      aws: &aws-config
        default_key_name: ${PUBLIC_KEY_NAME}
        default_security_groups: ["${SECURITY_GROUP}"]
        region: "${AWS_REGION_NAME}"
        access_key_id: ${AWS_ACCESS_KEY}
        secret_access_key: ${AWS_SECRET_KEY}

cloud_provider:
  template: {name: aws_cpi, release: bosh-aws-cpi}

  ssh_tunnel:
    host: ${DIRECTOR_EIP}
    port: 22
    user: vcap
    private_key: ${shared_key}

  mbus: "https://mbus:mbus-password@${DIRECTOR_EIP}:6868"

  properties:
    aws: *aws-config

    # Tells CPI how agent should listen for requests
    agent: {mbus: "https://mbus:mbus-password@0.0.0.0:6868"}

    blobstore:
      provider: local
      path: /var/vcap/micro_bosh/data/cache

    ntp: *ntp
EOF

cat > "${OUTPUT_DIR}/cloud-config.yml" <<EOF
azs:
- name: z1
  cloud_properties: {availability_zone: ${AVAILABILITY_ZONE}}

vm_types:
- name: default
  cloud_properties:
    instance_type: t2.micro
    ephemeral_disk: {size: 3000}

disk_types:
- name: default
  disk_size: 3000
  cloud_properties: {}

networks:
- name: default
  type: manual
  subnets:
  - range:    ${AWS_NETWORK_CIDR}
    gateway:  ${AWS_NETWORK_GATEWAY}
    az:       z1
    dns:      [8.8.8.8]
    static:   [${STATIC_RANGE}]
    reserved:   [${RESERVED_RANGE}]
    cloud_properties: {subnet: ${SUBNET_ID}}
- name: vip
  type: vip

compilation:
  workers: 5
  reuse_compilation_vms: true
  az: z1
  vm_type: default
  network: default
EOF

echo -e "${green}Successfully generated manifest!${nc}"
echo -e "${green}Manifest:    ${OUTPUT_DIR}/director.yml${nc}"
echo -e "${green}Env:         ${OUTPUT_DIR}/director.env${nc}"
echo -e "${green}CloudConfig: ${OUTPUT_DIR}/cloud-config.yml${nc}"
echo -e "${green}Artifacts:   ${tmpdir}/${nc}"
