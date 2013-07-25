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

# unmap the loop device in case it's already mapped
kpartx -dvs $work/$disk_image_name

# Map partition in image to loopback
dev=$(kpartx -avs $work/$disk_image_name | grep "^add" | cut -d" " -f3)
loopback_dev="/dev/mapper/$dev"

# Format partition
mkfs.$part_fs $loopback_dev

# Mount partition
mnt=$work/mnt
mkdir -p $mnt
mount $loopback_dev $mnt

# Copy root
time rsync -aHA $chroot/ $mnt

# Unmount partition
echo "Unmounting $mnt"
for try in $(seq 0 9); do
  sleep $try
  echo -n "."
  umount $mnt || continue
  break
done
echo

if mountpoint -q $mnt; then
  echo "Could not unmount $mnt after 10 tries"
  exit 1
fi

# Unmap partition
echo "Removing device mappings for $disk_image_name"
for try in $(seq 0 9); do
  sleep $try
  echo -n "."
  kpartx -dvs $work/$disk_image_name || continue
  break
done

if [ -b $loopback_dev ]; then
  echo "Could not remove device mapping at $loopback_dev"
  exit 1
fi
