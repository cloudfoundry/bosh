#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

disk_image_name=root.img
disk_size=$image_create_disk_size

# Reserve the first 63 sectors for grub
part_offset=63s
part_size=$(($disk_size - 1))
part_fs=ext4

dd if=/dev/null of=$work/$disk_image_name bs=1M seek=$disk_size 2> /dev/null
parted --script $work/$disk_image_name mklabel msdos
parted --script $work/$disk_image_name mkpart primary ext2 $part_offset $part_size

# Map partition in image to loopback
dev=$(kpartx -av $work/$disk_image_name | grep "^add" | cut -d" " -f3)

# Format partition
mkfs.$part_fs /dev/mapper/$dev

# Mount partition
mnt=$work/mnt
mkdir -p $mnt
mount /dev/mapper/$dev $mnt

# Copy root
time rsync -aHA $chroot/ $mnt

# Unmount partition
umount $mnt

# Unmap partition
kpartx -dv $work/$disk_image_name
