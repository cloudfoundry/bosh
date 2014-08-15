#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

pkg_mgr install wireless-crda

mkdir -p $chroot/tmp

if [ "${DISTRIB_CODENAME}" == "lucid" ]; then
  cp $assets_dir/lucid/*.deb $chroot/tmp/

  run_in_chroot $chroot "dpkg -i /tmp/linux-headers-3.0.0-32_3.0.0-32.51~lucid1_all.deb"
  run_in_chroot $chroot "dpkg -i /tmp/linux-headers-3.0.0-32-virtual_3.0.0-32.51~lucid1_amd64.deb"
  run_in_chroot $chroot "dpkg -i /tmp/linux-image-3.0.0-32-virtual_3.0.0-32.51~lucid1_amd64.deb"

  rm $chroot/tmp/*.deb
else
  pkg_mgr install linux-generic
fi
