#!/usr/bin/env bash

set -eu

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
src_dir="${script_dir}/../../../"
node_number=${1}

pushd ${BOSH_DEPLOYMENT_PATH} > /dev/null
  inner_bosh_dir="/tmp/inner-bosh/director/$node_number"
  mkdir -p ${inner_bosh_dir}

  export BOSH_DIRECTOR_IP="10.245.0.$((10+$node_number))"

  bosh int bosh.yml \
    -o bosh-lite.yml \
    -o "$script_dir/inner-bosh-ops.yml" \
    -o jumpbox-user.yml \
    -v director_name=warden-inner \
    -v internal_ip="${BOSH_DIRECTOR_IP}" \
    -v network=default \
    -v stemcell_os="${STEMCELL_OS}" \
    -o "${BOSH_DEPLOYMENT_PATH}/misc/source-releases/bosh.yml" \
    -o "$script_dir/latest-bosh-release.yml" \
    -o "$script_dir/deployment-name.yml" \
    -v deployment_name="bosh-$node_number" \
    ${@:2} > "${inner_bosh_dir}/bosh-director.yml"

  bosh -n deploy -d "bosh-$node_number" "${inner_bosh_dir}/bosh-director.yml" --vars-store="${inner_bosh_dir}/creds.yml"

  # set up inner director
  export BOSH_ENVIRONMENT="warden-inner-director-${node_number}"
  export BOSH_CONFIG="${inner_bosh_dir}/config"

  bosh int "${inner_bosh_dir}/creds.yml" --path /director_ssl/ca > "${inner_bosh_dir}/ca.crt"
  bosh -e "${BOSH_DIRECTOR_IP}" --ca-cert "${inner_bosh_dir}/ca.crt" alias-env "${BOSH_ENVIRONMENT}"

  bosh int "${inner_bosh_dir}/creds.yml" --path /jumpbox_ssh/private_key > "${inner_bosh_dir}/jumpbox_private_key.pem"
  chmod 600 "${inner_bosh_dir}/jumpbox_private_key.pem"

  cat <<EOF > "${inner_bosh_dir}/bosh"
#!/bin/bash

export BOSH_CONFIG="${BOSH_CONFIG}"
export BOSH_ENVIRONMENT="${BOSH_ENVIRONMENT}"
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh int "${inner_bosh_dir}/creds.yml" --path /admin_password`
export BOSH_CA_CERT="${inner_bosh_dir}/ca.crt"

$(which bosh) "\$@"
EOF

  chmod +x "${inner_bosh_dir}/bosh"

  "${inner_bosh_dir}/bosh" -n update-cloud-config \
    "$script_dir/inner-bosh-cloud-config.yml" \
    -v node_number="${node_number}"

popd > /dev/null
