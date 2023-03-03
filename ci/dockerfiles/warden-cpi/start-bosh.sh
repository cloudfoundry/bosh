#!/usr/bin/env bash

set -e

local_bosh_dir="/tmp/local-bosh/director"

/var/vcap/jobs/garden/bin/pre-start
/var/vcap/jobs/garden/bin/garden_ctl start &
/var/vcap/jobs/garden/bin/post-start

additional_ops_files=""
if [ "${USE_LOCAL_RELEASES}" != "false" ]; then
  additional_ops_files="/usr/local/releases/local-releases.yml"
fi

pushd ${BOSH_DEPLOYMENT_PATH:-/usr/local/bosh-deployment} > /dev/null
  export BOSH_DIRECTOR_IP="192.168.56.6"

  mkdir -p ${local_bosh_dir}

  bosh create-env bosh.yml \
    -o bosh-lite.yml \
    -o warden/cpi.yml \
    -o uaa.yml \
    -o credhub.yml \
    ${additional_ops_files} \
    --state "${local_bosh_dir}/state.json" \
    --vars-store "${local_bosh_dir}/creds.yml" \
    -v director_name=bosh-lite \
    -v internal_ip=${BOSH_DIRECTOR_IP} \
    -v internal_gw=192.168.56.1 \
    -v internal_cidr=192.168.56.0/24 \
    -v outbound_network_name=NatNetwork \
    -v garden_host=127.0.0.1 \
    ${@}

  bosh int "${local_bosh_dir}/creds.yml" --path /director_ssl/ca > "${local_bosh_dir}/ca.crt"

  cat <<EOF > "${local_bosh_dir}/env"
export BOSH_ENVIRONMENT="${BOSH_DIRECTOR_IP}"
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh int "${local_bosh_dir}/creds.yml" --path /admin_password`
export BOSH_CA_CERT="${local_bosh_dir}/ca.crt"
EOF
  source "${local_bosh_dir}/env"

  bosh -n update-cloud-config warden/cloud-config.yml
  ip route add   10.244.0.0/16 via ${BOSH_DIRECTOR_IP}
popd > /dev/null
