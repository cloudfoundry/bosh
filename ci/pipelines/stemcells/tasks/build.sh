#!/bin/bash

set -e

source bosh-src/ci/tasks/utils.sh
check_param IAAS
check_param HYPERVISOR
check_param OS_NAME
check_param OS_VERSION

export TASK_DIR=$PWD
export CANDIDATE_BUILD_NUMBER=$( cat version/number | sed 's/\.0$//;s/\.0$//' )

git clone stemcells-index stemcells-index-output

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

sudo chmod u+s $(which sudo)

if [ $IAAS = "warden" ]; then
sudo --preserve-env --set-home --user ubuntu -- /bin/bash --login -i <<SUDO
  pushd bosh-src/go/src/github.com/cloudfoundry/bosh-agent
    git checkout 48ed0810c66cdebe3ddb8ca300bbec2255fb8f1d # warden_stemcell branch HEAD
  popd
SUDO
fi

sudo --preserve-env --set-home --user ubuntu -- /bin/bash --login -i <<SUDO
  set -e

  cd bosh-src

  bundle install --local
  bundle exec rake stemcell:build[$IAAS,$HYPERVISOR,$OS_NAME,$OS_VERSION,go,bosh-os-images,bosh-$OS_NAME-$OS_VERSION-os-image.tgz]
  rm -f ./tmp/base_os_image.tgz
SUDO

#
# Output and checksum the stemcell artifacts
#

stemcell_name="bosh-stemcell-$CANDIDATE_BUILD_NUMBER-$IAAS-$HYPERVISOR-$OS_NAME-$OS_VERSION-go_agent"
meta4_path=$TASK_DIR/stemcells-index-output/dev/$OS_NAME-$OS_VERSION/$CANDIDATE_BUILD_NUMBER/$IAAS-$HYPERVISOR-go_agent.meta4

mkdir -p "$( dirname "$meta4_path" )"
meta4 create --metalink="$meta4_path"

if [ -e bosh-src/src/tmp/*-raw.tgz ] ; then
  # openstack currently publishes raw files
  raw_stemcell_filename="${stemcell_name}-raw.tgz"
  mv bosh-src/src/tmp/*-raw.tgz "stemcell/${raw_stemcell_filename}"

  meta4 import-file --metalink="$meta4_path" --version="$version" "stemcell/${raw_stemcell_filename}"
  meta4 file-set-url --metalink="$meta4_path" --file="${raw_stemcell_filename}" "https://s3.amazonaws.com/bosh-core-stemcells/${IAAS}/${raw_stemcell_filename}"
fi

stemcell_filename="${stemcell_name}.tgz"
mv "bosh-src/src/tmp/${stemcell_filename}" "stemcell/${stemcell_filename}"

meta4 import-file --metalink="$meta4_path" --version="$version" "stemcell/${stemcell_filename}"
meta4 file-set-url --metalink="$meta4_path" --file="${stemcell_filename}" "https://s3.amazonaws.com/bosh-core-stemcells/${IAAS}/${stemcell_filename}"

# just in case we need to debug/verify the live results
cat "$meta4_path"

cd stemcells-index-output

git add -A
git config --global user.email "ci@localhost"
git config --global user.name "CI Bot"
git commit -m "dev: $OS_NAME-$OS_VERSION/$CANDIDATE_BUILD_NUMBER ($IAAS-$HYPERVISOR)"
