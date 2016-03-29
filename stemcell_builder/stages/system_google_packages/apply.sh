#!/usr/bin/env bash
# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Install Google Daemon and Google Startup Scripts packages
mkdir -p $chroot/tmp
if [ -f $chroot/etc/debian_version ] # Ubuntu
then
  cp $assets_dir/google-compute-daemon_*.deb $chroot/tmp
  cp $assets_dir/google-startup-scripts_*.deb $chroot/tmp

  run_in_chroot $chroot "dpkg -i /tmp/google-compute-daemon_*.deb /tmp/google-startup-scripts_*.deb  || true"
  pkg_mgr install

  rm -f /tmp/google-compute-daemon_*.deb
  rm -f /tmp/google-startup-scripts_*.deb
elif [ -f $chroot/etc/redhat-release ] # Centos or RHEL
then
  cp $assets_dir/google-compute-daemon-*.rpm $chroot/tmp
  cp $assets_dir/google-startup-scripts-*.rpm $chroot/tmp

  run_in_chroot $chroot "yum -y install /tmp/google-compute-daemon-*.rpm /tmp/google-startup-scripts-*.rpm"

  rm -f /tmp/google-compute-daemon-*.rpm
  rm -f /tmp/google-startup-scripts-*.rpm
else
  echo "Unknown OS, exiting"
  exit 2
fi
