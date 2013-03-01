#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# Only install open-vm-tools on lucid
[ $DISTRIB_CODENAME != "lucid" ] && exit 0

mkdir -p $chroot/tmp
cp $assets_dir/open-vm-*.deb $chroot/tmp

# open-vm-tools needed to be backported to work with the 2.6.38 kernel
# https://bugs.launchpad.net/ubuntu/+source/open-vm-tools/+bug/746152
run_in_chroot $chroot "dpkg -i /tmp/open-vm-*.deb || true"

# Fix missing dependencies for the open-vm debs
apt_get install

# Remove debs
run_in_chroot $chroot "rm -f /tmp/*.deb"

run_in_chroot $chroot "
ln -s /etc/init.d/open-vm-tools /etc/rc2.d/S88open-vm-tools
"

# replace vmxnet3 from included kernel
mkdir -p $chroot/tmp
cp $assets_dir/vmware-tools-vmxnet3-modules-source_1.0.36.0-2_amd64.deb $chroot/tmp
cp $assets_dir/vmware-tools-install.sh $chroot/tmp

run_in_chroot $chroot "
dpkg -i /tmp/vmware-tools-vmxnet3-modules-source_1.0.36.0-2_amd64.deb
rm -f /tmp/*.deb
/tmp/vmware-tools-install.sh
"
