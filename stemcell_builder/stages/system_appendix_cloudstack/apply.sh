#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# requreid by stemcell-copy-cloudstack.sh
pkg_mgr install parted

# workaorund for a kernel bug
if [ $DISTRIB_CODENAME == "lucid" ]
then
  pkg_mgr install wireless-crda
  for file in linux-headers-3.2.0-030200_3.2.0-030200.201201042035_all.deb \
              linux-headers-3.2.0-030200-generic_3.2.0-030200.201201042035_amd64.deb \
              linux-image-3.2.0-030200-generic_3.2.0-030200.201201042035_amd64.deb; do
    run_in_chroot $chroot "
    cd /tmp
    wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v3.2-precise/${file}
    dpkg -i $file
    rm $file
    "
  done
fi
