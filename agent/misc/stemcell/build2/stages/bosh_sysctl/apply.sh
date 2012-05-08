#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

cp $dir/assets/60-bosh-sysctl.conf $chroot/etc/sysctl.d
chmod 0644 $chroot/etc/sysctl.d/60-bosh-sysctl.conf
