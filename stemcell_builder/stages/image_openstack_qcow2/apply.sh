#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

disk_image_name=root.img

qemu-img convert -O qcow2 $work/$disk_image_name $work/root.qcow2
rm $work/$disk_image_name
mv $work/root.qcow2 $work/$disk_image_name