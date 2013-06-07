#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

disk_image_name=root.img

# unmap the loop device in case it's already mapped
kpartx -dvs $work/$disk_image_name

# Map partition in image to loopback
dev=$(kpartx -avs $work/$disk_image_name | grep "^add" | cut -d" " -f3)
loopback_dev="/dev/mapper/$dev"

# Mount partition
mnt=$work/mnt
mkdir -p $mnt
mount $loopback_dev $mnt

# Pass virtual console device to kernel
sed -i -e "s/^# defoptions=.*/# defoptions=console=hvc0/" $mnt/boot/grub/menu.lst

# Regenerate menu.lst
chroot $mnt update-grub
rm -f $mnt/boot/grub/menu.lst~

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