#!/usr/bin/env bash
# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Copy google daemon packages into chroot
cp -R $assets_dir/usr $chroot/

os_type="$(get_os_type)"
if [ "${os_type}" == "ubuntu" ]
then
  # Run google-accounts-manager and google-clock-sync-manager with upstart
  cp $assets_dir/etc/init/google-accounts-manager-{task,service}.conf $chroot/etc/init/
  cp $assets_dir/google-address-manager.conf $chroot/etc/init/
  cp $assets_dir/google-clock-sync-manager.conf $chroot/etc/init/
  chmod -x $chroot/etc/init/google*
elif [ "${os_type}" == "rhel" -o "${os_type}" == "centos" ]
then
  run_in_chroot $chroot "/bin/systemctl enable /usr/lib/systemd/system/google-accounts-manager.service"
  run_in_chroot $chroot "/bin/systemctl enable /usr/lib/systemd/system/google-address-manager.service"
  run_in_chroot $chroot "/bin/systemctl enable /usr/lib/systemd/system/google-clock-sync-manager.service"
else
  echo "Unknown OS '${os_type}', exiting"
  exit 2
fi

# Hack: replace google metadata hostname with ip address (bosh agent might set a dns that it's unable to resolve the hostname)
run_in_chroot $chroot "find /usr/share/google -type f -exec sed -i 's/metadata.google.internal/169.254.169.254/g' {} +"
