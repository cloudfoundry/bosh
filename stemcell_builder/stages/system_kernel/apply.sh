#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

if [ "${DISTRIB_CODENAME}" == "lucid" ]
then
  mkdir -p $chroot/tmp

  cp $assets_dir/*.deb $chroot/tmp/

  pkg_mgr install wireless-crda

  run_in_chroot $chroot "dpkg -i /tmp/linux-headers-3.0.0-32_3.0.0-32.51~lucid1_all.deb"
  run_in_chroot $chroot "dpkg -i /tmp/linux-headers-3.0.0-32-virtual_3.0.0-32.51~lucid1_amd64.deb"
  run_in_chroot $chroot "dpkg -i /tmp/linux-image-3.0.0-32-virtual_3.0.0-32.51~lucid1_amd64.deb"

  rm $chroot/tmp/*.deb
else
  pkg_mgr install linux-virtual
  pkg_mgr install linux-image-extra-virtual
fi
