#!/usr/bin/env bash

set -eu

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
src_dir="${script_dir}/../../../"

cd /usr/local/bosh-deployment

local_bosh_dir="/tmp/local-bosh/director"
inner_bosh_dir="/tmp/inner-bosh/director"

export BOSH_DIRECTOR_IP="10.245.0.34"
export DOCKER_CERTS="$(bosh int /tmp/local-bosh/director/bosh-director.yml --path /instance_groups/0/properties/docker_cpi/docker/tls)"
export DOCKER_HOST="$(bosh int /tmp/local-bosh/director/bosh-director.yml --path /instance_groups/name=bosh/properties/docker_cpi/docker/host)"

mkdir -p ${inner_bosh_dir}

bosh int bosh.yml \
  -o "$script_dir/inner-bosh-ops.yml" \
  -o jumpbox-user.yml \
  -v director_name=docker-inner \
  -v internal_cidr=10.245.0.0/16 \
  -v internal_gw=10.245.0.1 \
  -v internal_ip="${BOSH_DIRECTOR_IP}" \
  -v docker_host="${DOCKER_HOST}" \
  -v network=director_network \
  -v docker_tls="${DOCKER_CERTS}" \
  -o /usr/local/bosh-deployment/local-bosh-release.yml \
  -v local_bosh_release="${src_dir}" \
  ${@} > "${inner_bosh_dir}/bosh-director.yml"

bosh upload-stemcell \
  --sha1=70c2584a8ad8e2b417c32809c34377728a6d6f86 \
  --name=bosh-warden-boshlite-ubuntu-trusty-go_agent \
  --version=3363.20 \
  https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent?v=3363.20

# point to our outer director and launch the inner director
source "${local_bosh_dir}/env"
bosh -n deploy -d bosh "${inner_bosh_dir}/bosh-director.yml" --vars-store="${inner_bosh_dir}/creds.yml"

# set up inner director
export BOSH_ENVIRONMENT="docker-inner-director"

bosh int "${inner_bosh_dir}/creds.yml" --path /director_ssl/ca > "${inner_bosh_dir}/ca.crt"
bosh -e "${BOSH_DIRECTOR_IP}" --ca-cert "${inner_bosh_dir}/ca.crt" alias-env "${BOSH_ENVIRONMENT}"

bosh int "${inner_bosh_dir}/creds.yml" --path /jumpbox_ssh/private_key > "${inner_bosh_dir}/jumpbox_private_key.pem"
chmod 400 "${inner_bosh_dir}/jumpbox_private_key.pem"

cat <<EOF > "${inner_bosh_dir}/bosh"
#!/bin/bash

export BOSH_ENVIRONMENT="${BOSH_ENVIRONMENT}"
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh int "${inner_bosh_dir}/creds.yml" --path /admin_password`
export BOSH_CA_CERT="${inner_bosh_dir}/ca.crt"

$(which bosh) "\$@"
EOF

chmod +x "${inner_bosh_dir}/bosh"

# reserve outer bosh's IP
cat <<EOF > "${inner_bosh_dir}/cloud-config-ops.yml"
- type: replace
  path: /networks/name=default/subnets/0/reserved?
  value:
  - 10.245.0.3
EOF

"${inner_bosh_dir}/bosh" -n update-cloud-config \
  "docker/cloud-config.yml" \
  -o "${inner_bosh_dir}/cloud-config-ops.yml" \
  -v network=director_network
