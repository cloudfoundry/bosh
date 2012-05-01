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

# Install bootloader
mkdir -p $mnt/tmp/grub

touch $mnt/tmp/grub/$disk_image_name
mount --bind $work/$disk_image_name $mnt/tmp/grub/$disk_image_name

cat > $mnt/tmp/grub/device.map <<EOS
(hd0) $disk_image_name
EOS

chroot $mnt <<EO1
cd /tmp/grub
grub --device-map=device.map --batch <<EO2
root (hd0,0)
setup (hd0)
EO2
EO1

# Figure out uuid of partition
uuid=$(blkid -c /dev/null -sUUID -ovalue /dev/mapper/$dev)

# Recreate vanilla menu.lst
rm -f $mnt/boot/grub/menu.lst*
chroot $mnt update-grub -y

# Modify root disk parameters to use the root partition's UUID
sed -i -e "s/^# kopt=root=\([^ ]*\)/# kopt=root=UUID=$uuid/" $mnt/boot/grub/menu.lst

# NOTE: Don't change "groot" to use a UUID. The pv-boot grub mechanism on EC2
# can't use this to figure out which device contains the kernel. It does
# understand "root (hd0,0)", which is the default.

# Regenerate menu.lst
chroot $mnt update-grub
rm -f $mnt/boot/grub/menu.lst~

# Clean up bootloader stuff
umount $mnt/tmp/grub/$disk_image_name
rm -rf $mnt/tmp/grub

# Unmount partition
umount $mnt

# Unmap partition
kpartx -dv $work/$disk_image_name
