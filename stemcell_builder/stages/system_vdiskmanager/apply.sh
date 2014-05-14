#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# Install qemu-img
pkg_mgr install "qemu"

mkdir -p $chroot/tmp
cp $assets_dir/vdiskmanager.tar $chroot/tmp
cp $assets_dir/vdiskmanager-install.sh $chroot/tmp

run_in_chroot $chroot "
/tmp/vdiskmanager-install.sh
"