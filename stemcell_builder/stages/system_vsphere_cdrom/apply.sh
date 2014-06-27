#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

cp $assets_dir/95-bosh-cdrom.rules $chroot/etc/udev/rules.d/95-bosh-cdrom.rules

install -m0755 $assets_dir/ready_cdrom.sh $chroot/etc/udev/rules.d/ready_cdrom.sh

if [ "${stemcell_operating_system_version}" == "trusty" ]; then
  cp $assets_dir/60-cdrom_id.rules $chroot/etc/udev/rules.d/60-cdrom_id.rules
fi
