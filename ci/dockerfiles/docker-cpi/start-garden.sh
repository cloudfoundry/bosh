#!/usr/bin/env bash

set -e

permit_device_control() {
  local devices_mount_info
  devices_mount_info=$(grep devices /proc/self/cgroup)

  if [ -z "$devices_mount_info" ]; then
    # cgroups not set up; must not be in a container
    return
  fi

  local devices_subsytems
  local devices_subdir
  devices_subsytems="$(echo "$devices_mount_info" | cut -d: -f2)"
  devices_subdir="$(echo "$devices_mount_info" | cut -d: -f3)"

  if [ "$devices_subdir" = "/" ]; then
    # we're in the root devices cgroup; must not be in a container
    return
  fi

  RUN_DIR=$(mktemp -d)
  cgroup_dir=${RUN_DIR}/devices-cgroup

  if [ ! -e "${cgroup_dir}" ]; then
    # mount our container's devices subsystem somewhere
    mkdir "${cgroup_dir}"
  fi

  if ! mountpoint -q "${cgroup_dir}"; then
    mount -t cgroup -o "$devices_subsytems" none "${cgroup_dir}"
  fi

  # permit our cgroup to do everything with all devices
  echo a > "${cgroup_dir}${devices_subdir}/devices.allow"

  umount "${cgroup_dir}"
}

create_loop_devices() {
  set +e
  LOOP_CONTROL=/dev/loop-control
  if [ ! -c $LOOP_CONTROL ]; then
    mknod $LOOP_CONTROL c 10 237
    chown root:disk $LOOP_CONTROL
    chmod 660 $LOOP_CONTROL
  fi
  amt=${1:-256}
  for i in $(seq 0 "$amt"); do
    if ! mknod -m 0660 "/dev/loop$i" b 7 "$i"; then
      break
    fi
  done
  set -e
}

main() {
  echo "nameserver 8.8.8.8" > /etc/resolv.conf

  # check for /proc/sys being mounted readonly, as systemd does
  if ! grep -qs '/sys' /proc/mounts; then
    mount -t sysfs sysfs /sys
  fi

  # shellcheck source=/dev/null
  permit_device_control
  create_loop_devices 256

  local mtu
  local tmpdir
  mtu=$(cat "/sys/class/net/$(ip route get 8.8.8.8 | awk '{ print $5 }')"/mtu)
  tmpdir=$(mktemp -d)

  local depot_path=$tmpdir/depot

  mkdir -p "$depot_path"

  export TMPDIR=$tmpdir
  export TEMP=$tmpdir
  export TMP=$tmpdir

  # GARDEN_GRAPH_PATH is the root of the docker image filesystem
  export GARDEN_GRAPH_PATH=/tmp/garden/graph
  mkdir -p "${GARDEN_GRAPH_PATH}"
  truncate -s 8G /tmp/garden/graph-sparse
  yes | mkfs -t ext4 /tmp/garden/graph-sparse
  mount -t ext4 /tmp/garden/graph-sparse "${GARDEN_GRAPH_PATH}"

  # we need a non-layered filesystem to be able to nest garden
  mkdir -p /var/vcap
  truncate -s 12G /tmp/garden/var-vcap
  yes | mkfs -t ext4 /tmp/garden/var-vcap
  mount -t ext4 /tmp/garden/var-vcap /var/vcap

  /opt/garden/bin/gdn server \
    --allow-host-access \
    --depot "$depot_path" \
    --bind-ip 0.0.0.0 --bind-port 7777 \
    --mtu "$mtu" \
    &
}

main "$@"
