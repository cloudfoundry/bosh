#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

debs="scsitools mg htop module-assistant debhelper runit"

apt_get install $debs

# `rescan-scsi-bus` doesn't have the `.sh` suffix on Ubuntu Precise
pushd $chroot/sbin
if [ ! -f rescan-scsi-bus.sh ]
then
  ln -s rescan-scsi-bus rescan-scsi-bus.sh
fi
popd
