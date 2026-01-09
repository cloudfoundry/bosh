#!/usr/bin/env bash

set -e
if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
fi

local_bosh_dir="/tmp/local-bosh/director"

# Update the on-container garden ini so that systemd is used as the INIT binary
# See: https://github.com/cloudfoundry/bosh-warden-cpi-release/commit/434738fed168b71cc0c3ba8c038773cc1074189e#diff-f3d9c00d365d08274b8e73e1dc4fc4b2d38a92a654d4d2b27f4ffdc01730576bR1-R8
sed -i 's/\/var\/vcap\/data\/garden\/bin\/init/\/sbin\/init/' /var/vcap/jobs/garden/config/config.ini

/var/vcap/jobs/garden/bin/pre-start
/var/vcap/jobs/garden/bin/garden_ctl start &
/var/vcap/jobs/garden/bin/post-start

additional_ops_files=""
if [ "${USE_LOCAL_RELEASES:="true"}" != "false" ]; then
  additional_ops_files="-o /usr/local/local-releases.yml"
fi

pushd "${BOSH_DEPLOYMENT_PATH:-/usr/local/bosh-deployment}" > /dev/null
  export BOSH_DIRECTOR_IP="192.168.56.6"

  mkdir -p ${local_bosh_dir}

  # shellcheck disable=SC2086
  bosh int bosh.yml \
    -o bosh-lite.yml \
    -o warden/cpi.yml \
    -o uaa.yml \
    -o credhub.yml \
    -o jumpbox-user.yml \
    ${additional_ops_files} \
    -v director_name=bosh-lite \
    -v internal_ip=${BOSH_DIRECTOR_IP} \
    -v internal_gw=192.168.56.1 \
    -v internal_cidr=192.168.56.0/24 \
    -v outbound_network_name=NatNetwork \
    -v garden_host=127.0.0.1 \
    "${@}" > "${local_bosh_dir}/bosh-director.yml"

  bosh create-env "${local_bosh_dir}/bosh-director.yml" \
       --vars-store="${local_bosh_dir}/creds.yml" \
       --state="${local_bosh_dir}/state.json"

  bosh int "${local_bosh_dir}/creds.yml" --path /director_ssl/ca \
    > "${local_bosh_dir}/ca.crt"
  bosh_client_secret="$(bosh int "${local_bosh_dir}/creds.yml" --path /admin_password)"

  cat <<EOF > "${local_bosh_dir}/env"
export BOSH_ENVIRONMENT="${BOSH_DIRECTOR_IP}"
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=${bosh_client_secret}
export BOSH_CA_CERT="${local_bosh_dir}/ca.crt"

EOF

      echo "Source '${local_bosh_dir}/env' to run bosh" >&2
  source "${local_bosh_dir}/env"

  bosh -n update-cloud-config warden/cloud-config.yml

  ip route add   10.244.0.0/15 via ${BOSH_DIRECTOR_IP}

popd > /dev/null
