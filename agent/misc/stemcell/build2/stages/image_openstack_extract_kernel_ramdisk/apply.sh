#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

disk_image_name=root.img
kernel_image_name=kernel.img
ramdisk_image_name=initrd.img

# Associate first unused loop device to image
loop_device=$(losetup -f --show $work/$disk_image_name)

# Mount partition
mnt=$work/mnt
mkdir -p $mnt
mount $loop_device $mnt

# Find and copy kernel
vmlinuz_file=$(find $mnt/boot/ -name "vmlinuz-*")
if [ -e "${vmlinuz_file:-}" ]
then
  cp $vmlinuz_file $work/$kernel_image_name
fi

# Find and copy ramdisk
initrd_file=$(find $mnt/boot/ -name "initrd*")
if [ -e "${initrd_file:-}" ]
then
  cp $initrd_file $work/$ramdisk_image_name
fi

# Unmount partition
umount $mnt

# Detach the image from the loop device
sleep 1
losetup -d $loop_device