#!/usr/bin/env bash
# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Configure the Google guest environment
# https://github.com/GoogleCloudPlatform/compute-image-packages#configuration
cp $assets_dir/instance_configs.cfg.template $chroot/etc/default/

mkdir -p $chroot/tmp/google

os_type="$(get_os_type)"
if [ "${os_type}" == "ubuntu" ]
then
  # Copy google daemon packages into chroot
  cp -R $assets_dir/google-ubuntu/*.deb $chroot/tmp/google/

  run_in_chroot $chroot "apt-get update"
  run_in_chroot $chroot "apt-get install -y python-setuptools python-boto"
  run_in_chroot $chroot "dpkg --unpack /tmp/google/*.deb"
  run_in_chroot $chroot "rm /var/lib/dpkg/info/google-compute-engine-init-trusty.postinst"
  run_in_chroot $chroot "dpkg --configure google-compute-engine-init-trusty google-config-trusty google-compute-engine-trusty"
  run_in_chroot $chroot "apt-get install -yf"

  # Hack: replace google metadata hostname with ip address (bosh agent might set a dns that it's unable to resolve the hostname)
  run_in_chroot $chroot "sed -i 's/metadata.google.internal/169.254.169.254/g' /usr/lib/python2.7/dist-packages/google_compute_engine/metadata_watcher.py"
elif [ "${os_type}" == "rhel" -o "${os_type}" == "centos" ]
then
  # Copy google daemon packages into chroot
  cp -R $assets_dir/google-centos/*.rpm $chroot/tmp/google/

  run_in_chroot $chroot "yum install -y python-setuptools python-boto"

  run_in_chroot $chroot "yum --nogpgcheck install -y /tmp/google/*.rpm"

  # Hack: replace google metadata hostname with ip address (bosh agent might set a dns that it's unable to resolve the hostname)
  run_in_chroot $chroot "sed -i 's/metadata.google.internal/169.254.169.254/g' /usr/lib/python2.7/site-packages/google_compute_engine/metadata_watcher.py"
else
  echo "Unknown OS '${os_type}', exiting"
  exit 2
fi

# See https://github.com/cloudfoundry/bosh/issues/1399 for context
run_in_chroot $chroot "rm -f /etc/dhcp/dhclient-exit-hooks.d/set_hostname"

