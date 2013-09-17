#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# unmap the loop device in case it's already mapped
kpartx -dvs $work/$disk_image_name

# Map partition in image to loopback
dev=$(kpartx -avs $work/$disk_image_name | grep "^add" | cut -d" " -f3)
loopback_dev="/dev/mapper/$dev"

# Mount partition
mnt=$work/mnt
mkdir -p $mnt
mount $loopback_dev $mnt

# Install bootloader
mkdir -p $mnt/tmp/grub

touch $mnt/tmp/grub/$disk_image_name

mount --bind $work/$disk_image_name $mnt/tmp/grub/$disk_image_name

cat > $mnt/tmp/grub/device.map <<EOS
(hd0) $disk_image_name
EOS

run_in_chroot $mnt "
cd /tmp/grub
grub --device-map=device.map --batch <<EOF
root (hd0,0)
setup (hd0)
EOF
"

# Figure out uuid of partition
uuid=$(blkid -c /dev/null -sUUID -ovalue /dev/mapper/$dev)

kernel_version=$(basename $(ls ${mnt}/boot/vmlinuz-* |tail -1) |cut -f2-8 -d'-')

if [ -f ${mnt}/etc/debian_version ] # Ubuntu
then
  initrd_file="initrd.img-${kernel_version}"
  os_name=$(source ${mnt}/etc/lsb-release ; echo -n ${DISTRIB_DESCRIPTION})
elif [ -f ${mnt}/etc/centos-release ] # Centos
then
  initrd_file="initramfs-${kernel_version}.img"
  os_name=$(cat ${mnt}/etc/centos-release)
  cat > ${mnt}/etc/fstab <<FSTAB
# /etc/fstab Created by BOSH Stemcell Builder
UUID=${uuid} / ext4 defaults 1 1
FSTAB
else
  echo "Unknown OS, exiting"
  exit 2
fi

cat > $mnt/boot/grub/grub.conf <<GRUB_CONF
default=0
timeout=1
title ${os_name} (${kernel_version})
  root (hd0,0)
  kernel /boot/vmlinuz-${kernel_version} ro root=UUID=${uuid}
  initrd /boot/${initrd_file}
GRUB_CONF

run_in_chroot $mnt "rm -f /boot/grub/menu.lst"
run_in_chroot $mnt "ln -s ./grub.conf /boot/grub/menu.lst"

# Clean up bootloader stuff
umount $mnt/tmp/grub/$disk_image_name
rm -rf $mnt/tmp/grub

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
