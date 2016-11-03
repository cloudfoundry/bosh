#!/usr/bin/env bash

set -e

: ${STEMCELL_NAME:?}
: ${BAT_VCAP_PASSWORD:?}
: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

# outputs
output_dir=$(realpath bats-config)
bats_spec="${output_dir}/bats-config.yml"
bats_env="${output_dir}/bats.env"

# inputs
bats_dir=$(realpath bats)
metadata=$(cat environment/metadata)
network1=$(env_attr "${metadata}" "network1")
network2=$(env_attr "${metadata}" "network2")
director_ip=$(env_attr "${metadata}" "directorIP")

: ${BAT_VLAN:=$(                          env_attr "${network1}" "vCenterVLAN")}
: ${BAT_STATIC_IP:=$(                     env_attr "${network1}" "staticIP-1")}
: ${BAT_SECOND_STATIC_IP:=$(              env_attr "${network1}" "staticIP-2")}
: ${BAT_CIDR:=$(                          env_attr "${network1}" "vCenterCIDR")}
: ${BAT_RESERVED_RANGE:=$(                env_attr "${network1}" "reservedRange")}
: ${BAT_STATIC_RANGE:=$(                  env_attr "${network1}" "staticRange")}
: ${BAT_GATEWAY:=$(                       env_attr "${network1}" "vCenterGateway")}
: ${BAT_SECOND_NETWORK_VLAN:=$(           env_attr "${network2}" "vCenterVLAN")}
: ${BAT_SECOND_NETWORK_STATIC_IP:=$(      env_attr "${network2}" "staticIP-1")}
: ${BAT_SECOND_NETWORK_CIDR:=$(           env_attr "${network2}" "vCenterCIDR")}
: ${BAT_SECOND_NETWORK_RESERVED_RANGE:=$( env_attr "${network2}" "reservedRange")}
: ${BAT_SECOND_NETWORK_STATIC_RANGE:=$(   env_attr "${network2}" "staticRange")}
: ${BAT_SECOND_NETWORK_GATEWAY:=$(        env_attr "${network2}" "vCenterGateway")}

# env file generation
cat > "${bats_env}" <<EOF
#!/usr/bin/env bash

export BAT_DIRECTOR=${director_ip}
export BAT_DNS_HOST=${director_ip}
export BAT_INFRASTRUCTURE=vsphere
export BAT_NETWORKING=manual
export BAT_VCAP_PASSWORD=${BAT_VCAP_PASSWORD}
export BAT_RSPEC_FLAGS="--tag ~vip_networking --tag ~dynamic_networking --tag ~root_partition --tag ~raw_ephemeral_storage"
export BAT_DIRECTOR_USER="${BOSH_DIRECTOR_USERNAME}"
export BAT_DIRECTOR_PASSWORD="${BOSH_DIRECTOR_PASSWORD}"
EOF

pushd "${bats_dir}" > /dev/null
  ./write_gemfile
  bundle install
  bundle exec bosh -n target "${director_ip}"
  BOSH_UUID="$(bundle exec bosh status --uuid)"
popd > /dev/null

cat > "${bats_spec}" <<EOF
---
cpi: vsphere
properties:
  uuid: ${BOSH_UUID}
  pool_size: 1
  instances: 1
  second_static_ip: ${BAT_SECOND_STATIC_IP}
  stemcell:
    name: ${STEMCELL_NAME}
    version: latest
  networks:
    - name: static
      type: manual
      static_ip: ${BAT_STATIC_IP}
      cidr: ${BAT_CIDR}
      reserved: [${BAT_RESERVED_RANGE}]
      static: [${BAT_STATIC_RANGE}]
      gateway: ${BAT_GATEWAY}
      vlan: ${BAT_VLAN}
    - name: second
      type: manual
      static_ip: ${BAT_SECOND_NETWORK_STATIC_IP}
      cidr: ${BAT_SECOND_NETWORK_CIDR}
      reserved: [${BAT_SECOND_NETWORK_RESERVED_RANGE}]
      static: [${BAT_SECOND_NETWORK_STATIC_RANGE}]
      gateway: ${BAT_SECOND_NETWORK_GATEWAY}
      vlan: ${BAT_SECOND_NETWORK_VLAN}
EOF
