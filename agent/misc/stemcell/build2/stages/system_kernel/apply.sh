#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

run_in_chroot $chroot "apt-get update"

if [ $DISTRIB_CODENAME == "lucid" ]
then
  variant="lts-backport-natty"

  # Headers are needed for open-vm-tools
  run_in_chroot $chroot "apt-get install -y --force-yes --no-install-recommends linux-image-virtual-${variant}"
  run_in_chroot $chroot "apt-get install -y --force-yes --no-install-recommends linux-headers-virtual-${variant}"
else
  run_in_chroot $chroot "apt-get install -y --force-yes --no-install-recommends linux-image-virtual"
fi

run_in_chroot $chroot "apt-get clean"
