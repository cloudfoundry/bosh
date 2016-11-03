#!/usr/bin/env bash

set -e

# environment

: ${AWS_ACCESS_KEY:?}
: ${AWS_SECRET_KEY:?}
: ${AWS_REGION_NAME:?}
: ${BAT_VCAP_PASSWORD:?}
: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}
: ${PUBLIC_KEY_NAME:?}
: ${STEMCELL_NAME:?}

source /etc/profile.d/chruby.sh
chruby 2.1.7

metadata=$(cat environment/metadata)

# configuration
: ${SECURITY_GROUP:=$(         echo ${metadata} | jq --raw-output ".SecurityGroupID" )}
: ${DIRECTOR_EIP:=$(           echo ${metadata} | jq --raw-output ".DirectorEIP" )}
: ${BATS_EIP:=$(               echo ${metadata} | jq --raw-output ".DeploymentEIP" )}
: ${SUBNET_ID:=$(              echo ${metadata} | jq --raw-output ".PublicSubnetID" )}
: ${AVAILABILITY_ZONE:=$(      echo ${metadata} | jq --raw-output ".AvailabilityZone" )}
: ${NETWORK_CIDR:=$(           echo ${metadata} | jq --raw-output ".PublicCIDR" )}
: ${NETWORK_GATEWAY:=$(        echo ${metadata} | jq --raw-output ".PublicGateway" )}
: ${NETWORK_RESERVED_RANGE:=$( echo ${metadata} | jq --raw-output ".ReservedRange" )}
: ${NETWORK_STATIC_RANGE:=$(   echo ${metadata} | jq --raw-output ".StaticRange" )}
: ${NETWORK_STATIC_IP_1:=$(    echo ${metadata} | jq --raw-output ".StaticIP1" )}
: ${NETWORK_STATIC_IP_2:=$(    echo ${metadata} | jq --raw-output ".StaticIP2" )}

# inputs
director_config=$(realpath director-config)

# outputs
output_dir=$(realpath bats-config)
bats_spec="${output_dir}/bats-config.yml"
bats_env="${output_dir}/bats.env"
ssh_key="${output_dir}/shared.pem"

# env file generation
cat > "${bats_env}" <<EOF
#!/usr/bin/env bash

export BAT_DIRECTOR=${DIRECTOR_EIP}
export BAT_DNS_HOST=${DIRECTOR_EIP}
export BAT_INFRASTRUCTURE=aws
export BAT_NETWORKING=manual
export BAT_VIP=${BATS_EIP}
export BAT_SUBNET_ID=${SUBNET_ID}
export BAT_SECURITY_GROUP_NAME=${SECURITY_GROUP}
export BAT_VCAP_PASSWORD=${BAT_VCAP_PASSWORD}
export BAT_VCAP_PRIVATE_KEY="bats-config/shared.pem"
export BAT_RSPEC_FLAGS="--tag ~multiple_manual_networks --tag ~root_partition"
export BAT_DIRECTOR_USER="${BOSH_DIRECTOR_USERNAME}"
export BAT_DIRECTOR_PASSWORD="${BOSH_DIRECTOR_PASSWORD}"
EOF

echo "using bosh CLI version..."
bosh version
bosh -n target ${DIRECTOR_EIP}
BOSH_UUID="$(bosh status --uuid)"

# BATs spec generation
cat > "${bats_spec}" <<EOF
---
cpi: aws
properties:
  vip: ${BATS_EIP}
  second_static_ip: ${NETWORK_STATIC_IP_2}
  uuid: ${BOSH_UUID}
  pool_size: 1
  stemcell:
    name: ${STEMCELL_NAME}
    version: latest
  instances: 1
  availability_zone: ${AVAILABILITY_ZONE}
  key_name:  ${PUBLIC_KEY_NAME}
  networks:
    - name: default
      static_ip: ${NETWORK_STATIC_IP_1}
      type: manual
      cidr: ${NETWORK_CIDR}
      reserved: [${NETWORK_RESERVED_RANGE}]
      static: [${NETWORK_STATIC_RANGE}]
      gateway: ${NETWORK_GATEWAY}
      subnet: ${SUBNET_ID}
      security_groups: [${SECURITY_GROUP}]
EOF

cp ${director_config}/shared.pem ${ssh_key}
