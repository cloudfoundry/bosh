#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

disk_image_name=root.img
partition_image_name=server.img

# Associate first unused loop device to image
loop_device=$(losetup -f --show $work/$disk_image_name)

# Find out the starting sector of the partition
# We assume 512 bytes per sector
start_sector=$(fdisk -c -u -l $loop_device | sed -e 's/  */\ /g' | grep "83 Linux" | cut -d" " -f2)
partition_offset=$(($start_sector * 512))

# Detach the image from the loop device
sleep 1
losetup -d $loop_device

# Associate first unused loop device to partition
loop_device=$(losetup -f --show -o $partition_offset $work/$disk_image_name)

# Copy the partition to a new file
dd if=$loop_device of=$work/$partition_image_name

# Detach the image the loop device
sleep 1
losetup -d $loop_device

# Delete the old disk image
rm $work/$disk_image_name

# Rename the new disk image
mv $work/$partition_image_name $work/$disk_image_name
