#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

disk_image_name=root.img
kernel_image_name=kernel.img
ramdisk_image_name=initrd.img

pushd $work

if [ ! -e "${kernel_image_name:-}" ]
then
  kernel_image_name=
fi

if [ ! -e "${ramdisk_image_name:-}" ]
then
  ramdisk_image_name=
fi

tar zcf stemcell/image $disk_image_name $kernel_image_name $ramdisk_image_name

popd
