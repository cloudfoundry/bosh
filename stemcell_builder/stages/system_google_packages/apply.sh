#!/usr/bin/env bash
# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Copy google daemon packages into chroot
cp -R $assets_dir/usr $chroot/

if [ -f $chroot/etc/debian_version ] # Ubuntu
then
  # Run google-accounts-manager and google-clock-sync-manager with upstart
  cp $assets_dir/etc/init/google-accounts-manager-{task,service}.conf $chroot/etc/init/
  cp $assets_dir/google-address-manager.conf $chroot/etc/init/
  cp $assets_dir/google-clock-sync-manager.conf $chroot/etc/init/
elif [ -f $chroot/etc/redhat-release ] # Centos or RHEL
then
  run_in_chroot $chroot "/bin/systemctl enable /usr/lib/systemd/system/google-accounts-manager.service"
  run_in_chroot $chroot "/bin/systemctl enable /usr/lib/systemd/system/google-address-manager.service"
  run_in_chroot $chroot "/bin/systemctl enable /usr/lib/systemd/system/google-clock-sync-manager.service"
else
  echo "Unknown OS, exiting"
  exit 2
fi
