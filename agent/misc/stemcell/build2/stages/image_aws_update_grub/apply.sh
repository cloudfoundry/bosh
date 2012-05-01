#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

disk_image_name=raw.img

# Map partition in image to loopback
dev=$(kpartx -av $work/$disk_image_name | grep "^add" | cut -d" " -f3)

# Mount partition
mnt=$work/mnt
mkdir -p $mnt
mount /dev/mapper/$dev $mnt

# Pass virtual console device to kernel
sed -i -e "s/^# defoptions=.*/# defoptions=console=hvc0/" $mnt/boot/grub/menu.lst

# Regenerate menu.lst
chroot $mnt update-grub
rm -f $mnt/boot/grub/menu.lst~

# Unmount partition
umount $mnt

# Unmap partition
kpartx -dv $work/$disk_image_name
