#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_common.bash
source $base_dir/lib/prelude_bosh.bash

# Set up users/groups
run_in_chroot $chroot "
addgroup --system admin
adduser --disabled-password --gecos Ubuntu vcap
echo vcap:c1oudc0w | chpasswd
echo root:c1oudc0w | chpasswd
"

for grp in admin adm audio cdrom dialout floppy video plugdev dip
do
  run_in_chroot $chroot "adduser vcap $grp"
done

cp $assets_dir/sudoers $chroot/etc/sudoers

echo "export PATH=$bosh_dir/bin:$PATH" >> $chroot/root/.bashrc
echo "export PATH=$bosh_dir/bin:$PATH" >> $chroot/home/vcap/.bashrc
