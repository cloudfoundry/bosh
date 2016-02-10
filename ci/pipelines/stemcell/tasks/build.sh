#!/bin/bash

set -e

source bosh-src/ci/tasks/utils.sh
check_param IAAS
check_param HYPERVISOR
check_param OS_NAME
check_param OS_VERSION

export TASK_DIR=$PWD
export CANDIDATE_BUILD_NUMBER=$( cat version/number | sed 's/\.0$//;s/\.0$//' )

# This is copied from https://github.com/concourse/concourse/blob/3c070db8231294e4fd51b5e5c95700c7c8519a27/jobs/baggageclaim/templates/baggageclaim_ctl.erb#L23-L54
# helps the /dev/mapper/control issue and lets us actually do scary things with the /dev mounts
# This allows us to create device maps from partition tables in image_create/apply.sh
function permit_device_control() {
  local devices_mount_info=$(cat /proc/self/cgroup | grep devices)

  local devices_subsytems=$(echo $devices_mount_info | cut -d: -f2)
  local devices_subdir=$(echo $devices_mount_info | cut -d: -f3)

  cgroup_dir=/mnt/tmp-todo-devices-cgroup

  if [ ! -e ${cgroup_dir} ]; then
    # mount our container's devices subsystem somewhere
    mkdir ${cgroup_dir}
  fi

  if ! mountpoint -q ${cgroup_dir}; then
    mount -t cgroup -o $devices_subsytems none ${cgroup_dir}
  fi

  # permit our cgroup to do everything with all devices
  # ignore failure in case something has already done this; echo appears to
  # return EINVAL, possibly because devices this affects are already in use
  echo a > ${cgroup_dir}${devices_subdir}/devices.allow || true
}

permit_device_control

# Also copied from baggageclaim_ctl.erb creates 64 loopback mappings. This fixes failures with losetup --show --find ${disk_image}
for i in $(seq 0 64); do
  if ! mknod -m 0660 /dev/loop$i b 7 $i; then
    break
  fi
done

chown -R ubuntu:ubuntu bosh-src
sudo --preserve-env --set-home --user ubuntu -- /bin/bash --login -i <<SUDO
  cd bosh-src

  bundle install --local
  bundle exec rake stemcell:build_with_local_os_image_with_bosh_release_tarball[$IAAS,$HYPERVISOR,$OS_NAME,$OS_VERSION,go,$TASK_DIR/os-image/*.tgz,$TASK_DIR/bosh-release/*.tgz,$CANDIDATE_BUILD_NUMBER]
SUDO

mkdir -p stemcell/

base_path="stemcell/bosh-stemcell-$CANDIDATE_BUILD_NUMBER-$IAAS-$HYPERVISOR-$OS_NAME-$OS_VERSION-go_agent"

if [ -e bosh-src/tmp/*-raw.tgz ] ; then
  # openstack currently publishes raw files
  mv bosh-src/tmp/*-raw.tgz $base_path-raw.tgz
  echo -n $(sha1sum $base_path-raw.tgz | awk '{print $1}') > $base_path-raw.tgz.sha1
fi

mv bosh-src/tmp/*.tgz $base_path.tgz
echo -n $(sha1sum $base_path.tgz | awk '{print $1}') > $base_path.tgz.sha1
