#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# Set up users/groups
run_in_chroot $chroot "
addgroup --system admin
adduser --disabled-password --gecos Ubuntu vcap
echo \"vcap:${bosh_users_password}\" | chpasswd
echo \"root:${bosh_users_password}\" | chpasswd
"

for grp in admin adm audio cdrom dialout floppy video plugdev dip
do
  run_in_chroot $chroot "adduser vcap $grp"
done

cp $assets_dir/sudoers $chroot/etc/sudoers

echo "export PATH=$bosh_dir/bin:$PATH" >> $chroot/root/.bashrc
echo "export PATH=$bosh_dir/bin:$PATH" >> $chroot/home/vcap/.bashrc
