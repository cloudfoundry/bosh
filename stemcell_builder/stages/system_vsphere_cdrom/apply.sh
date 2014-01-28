#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

cp $assets_dir/95-bosh-cdrom.rules $chroot/etc/udev/rules.d/95-bosh-cdrom.rules

cp $assets_dir/ready_cdrom.sh $chroot/etc/udev/rules.d/ready_cdrom.sh
