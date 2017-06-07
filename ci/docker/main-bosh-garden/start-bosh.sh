#!/usr/bin/env bash

set -e

permit_device_control() {
  local devices_mount_info=$(cat /proc/self/cgroup | grep devices)

  if [ -z "$devices_mount_info" ]; then
    # cgroups not set up; must not be in a container
    return
  fi

  local devices_subsytems=$(echo $devices_mount_info | cut -d: -f2)
  local devices_subdir=$(echo $devices_mount_info | cut -d: -f3)

  if [ "$devices_subdir" = "/" ]; then
    # we're in the root devices cgroup; must not be in a container
    return
  fi

  RUN_DIR=$(mktemp -d)
  cgroup_dir=${RUN_DIR}/devices-cgroup

  if [ ! -e ${cgroup_dir} ]; then
    # mount our container's devices subsystem somewhere
    mkdir ${cgroup_dir}
  fi

  if ! mountpoint -q ${cgroup_dir}; then
    mount -t cgroup -o $devices_subsytems none ${cgroup_dir}
  fi

  # permit our cgroup to do everything with all devices
  echo a > ${cgroup_dir}${devices_subdir}/devices.allow

  umount ${cgroup_dir}
}

create_loop_devices() {
  set +e
  amt=${1:-256}
  for i in $(seq 0 $amt); do
    if ! mknod -m 0660 /dev/loop$i b 7 $i; then
      break
    fi
  done
  set -e
}

start_garden() {
  echo "nameserver 8.8.8.8" > /etc/resolv.conf

  # check for /proc/sys being mounted readonly, as systemd does
  if ! grep -qs '/sys' /proc/mounts; then
    mount -t sysfs sysfs /sys
  fi

  # shellcheck source=/dev/null
  permit_device_control
  create_loop_devices 256

  local mtu=$(cat /sys/class/net/$(ip route get 8.8.8.8|awk '{ print $5 }')/mtu)
  local tmpdir=$(mktemp -d)

  local depot_path=$tmpdir/depot

  mkdir -p $depot_path

  export TMPDIR=$tmpdir
  export TEMP=$tmpdir
  export TMP=$tmpdir

  # GARDEN_GRAPH_PATH is the root of the docker image filesystem
  export GARDEN_GRAPH_PATH=/tmp/garden/graph
  mkdir -p "${GARDEN_GRAPH_PATH}"
  truncate -s 4G /tmp/garden/graph-sparse
  yes | mkfs -t ext4 /tmp/garden/graph-sparse
  mount -t ext4 /tmp/garden/graph-sparse "${GARDEN_GRAPH_PATH}"

  # we need a non-layered filesystem to be able to nest garden
  mkdir -p /var/vcap
  truncate -s 12G /tmp/garden/var-vcap
  yes | mkfs -t ext4 /tmp/garden/var-vcap
  mount -t ext4 /tmp/garden/var-vcap /var/vcap

  /opt/garden/bin/gdn server \
    --allow-host-access \
    --depot $depot_path \
    --bind-ip 0.0.0.0 --bind-port 7777 \
    --mtu $mtu \
    --graph=$GARDEN_GRAPH_PATH \
    &
}

main() {
  source /etc/profile.d/chruby.sh
  chruby 2.3.1

  export OUTER_CONTAINER_IP=$(ruby -rsocket -e 'puts Socket.ip_address_list
                          .reject { |addr| !addr.ip? || addr.ipv4_loopback? || addr.ipv6? }
                          .map { |addr| addr.ip_address }')

  export GARDEN_HOST=${OUTER_CONTAINER_IP}

  start_garden

  local local_bosh_dir
  local_bosh_dir="/tmp/local-bosh/director"

  pushd /usr/local/bosh-deployment > /dev/null
      export BOSH_DIRECTOR_IP="10.245.0.3"
      export BOSH_ENVIRONMENT="warden-director"

      mkdir -p ${local_bosh_dir}

      command bosh int bosh.yml \
        -o jumpbox-user.yml \
        -o bosh-lite.yml \
        -o bosh-lite-runc.yml \
        -o warden/cpi.yml \
        -v director_name=warden \
        -v internal_cidr=10.245.0.0/16 \
        -v internal_gw=10.245.0.1 \
        -v internal_ip="${BOSH_DIRECTOR_IP}" \
        -v garden_host="${GARDEN_HOST}" \
        ${@} > "${local_bosh_dir}/bosh-director.yml"

      command bosh create-env "${local_bosh_dir}/bosh-director.yml" \
              --vars-store="${local_bosh_dir}/creds.yml" \
              --state="${local_bosh_dir}/state.json"

      bosh int "${local_bosh_dir}/creds.yml" --path /director_ssl/ca > "${local_bosh_dir}/ca.crt"
      bosh -e "${BOSH_DIRECTOR_IP}" --ca-cert "${local_bosh_dir}/ca.crt" alias-env "${BOSH_ENVIRONMENT}"

      cat <<EOF > "${local_bosh_dir}/env"
      export BOSH_ENVIRONMENT="${BOSH_ENVIRONMENT}"
      export BOSH_CLIENT=admin
      export BOSH_CLIENT_SECRET=`bosh int "${local_bosh_dir}/creds.yml" --path /admin_password`
      export BOSH_CA_CERT="${local_bosh_dir}/ca.crt"

EOF
      source "${local_bosh_dir}/env"

      bosh -n update-cloud-config warden/cloud-config.yml

      route add -net 10.244.0.0/16 gw ${BOSH_DIRECTOR_IP}

  popd > /dev/null
}

main $@
