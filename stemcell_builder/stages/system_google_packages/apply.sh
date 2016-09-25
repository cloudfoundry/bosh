#!/usr/bin/env bash
# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

os_type="$(get_os_type)"
if [ "${os_type}" == "ubuntu" ]
then
  # Copy google daemon packages into chroot
  cp -R $assets_dir/*.deb $chroot/tmp/

  # Configure the Google guest environment
  # https://github.com/GoogleCloudPlatform/compute-image-packages#configuration
  cp $assets_dir/instance_configs.cfg.template $chroot/etc/default/

  run_in_chroot $chroot "apt-get update"
  run_in_chroot $chroot "apt-get install -y python-setuptools python-boto"
  run_in_chroot $chroot "dpkg --force-all -i /tmp/*.deb"
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
run_in_chroot $chroot "sed -i 's/metadata.google.internal/169.254.169.254/g' /usr/lib/python2.7/dist-packages/google_compute_engine/metadata_watcher.py"
