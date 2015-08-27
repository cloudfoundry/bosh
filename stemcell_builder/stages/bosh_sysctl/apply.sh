#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

if [ "${stemcell_operating_system}" == "ubuntu" -o "${stemcell_operating_system_version}" == "7" -o "${stemcell_operating_system}" == "photon" ]; then
  cp $dir/assets/60-bosh-sysctl.conf $chroot/etc/sysctl.d
  chmod 0644 $chroot/etc/sysctl.d/60-bosh-sysctl.conf
fi

# this stuff is required for all systems based on the Linux 3.x kernel
if [ "${stemcell_operating_system_version}" == "trusty" -o "${stemcell_operating_system_version}" == "7" -o "${stemcell_operating_system}" == "photon" ]; then
  cp $dir/assets/60-bosh-sysctl-neigh-fix.conf $chroot/etc/sysctl.d
  chmod 0644 $chroot/etc/sysctl.d/60-bosh-sysctl-neigh-fix.conf
fi
