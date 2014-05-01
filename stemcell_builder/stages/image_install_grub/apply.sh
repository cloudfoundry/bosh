#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

disk_image=${work}/${stemcell_image_name}

# unmap the loop device in case it's already mapped
kpartx -dv ${disk_image}

# Map partition in image to loopback
device=$(losetup --show --find ${disk_image})
device_partition=$(kpartx -av ${device} | grep "^add" | cut -d" " -f3)
loopback_dev="/dev/mapper/${device_partition}"

# Mount partition
image_mount_point=${work}/mnt
mkdir -p ${image_mount_point}
mount ${loopback_dev} ${image_mount_point}

# Install bootloader
mkdir -p ${image_mount_point}/tmp/grub

touch ${image_mount_point}/tmp/grub/${stemcell_image_name}

mount --bind $work/${stemcell_image_name} ${image_mount_point}/tmp/grub/${stemcell_image_name}

cat > ${image_mount_point}/tmp/grub/device.map <<EOS
(hd0) ${stemcell_image_name}
EOS

run_in_chroot ${image_mount_point} "
cd /tmp/grub
grub --device-map=device.map --batch <<EOF
root (hd0,0)
setup (hd0)
EOF
"

# Figure out uuid of partition
uuid=$(blkid -c /dev/null -sUUID -ovalue ${loopback_dev})

kernel_version=$(basename $(ls ${image_mount_point}/boot/vmlinuz-* |tail -1) |cut -f2-8 -d'-')

if [ -f ${image_mount_point}/etc/debian_version ] # Ubuntu
then
  initrd_file="initrd.img-${kernel_version}"
  os_name=$(source ${image_mount_point}/etc/lsb-release ; echo -n ${DISTRIB_DESCRIPTION})
elif [ -f ${image_mount_point}/etc/centos-release ] # Centos
then
  initrd_file="initramfs-${kernel_version}.img"
  os_name=$(cat ${image_mount_point}/etc/centos-release)
  cat > ${image_mount_point}/etc/fstab <<FSTAB
# /etc/fstab Created by BOSH Stemcell Builder
UUID=${uuid} / ext4 defaults 1 1
FSTAB
else
  echo "Unknown OS, exiting"
  exit 2
fi

if [ -f ${image_mount_point}/etc/debian_version ] # Ubuntu
then
cat > ${image_mount_point}/boot/grub/grub.conf <<GRUB_CONF
default=0
timeout=1
title ${os_name} (${kernel_version})
  root (hd0,0)
  kernel /boot/vmlinuz-${kernel_version} ro root=UUID=${uuid} selinux=0 cgroup_enable=memory swapaccount=1
  initrd /boot/${initrd_file}
GRUB_CONF
elif [ -f ${image_mount_point}/etc/centos-release ] # Centos
then
# We need to set xen_blkfront.sda_is_xvda=1 to force CentOS to
# have device mapping consistant with Ubuntu.
cat > ${image_mount_point}/boot/grub/grub.conf <<GRUB_CONF
default=0
timeout=1
title ${os_name} (${kernel_version})
  root (hd0,0)
  kernel /boot/vmlinuz-${kernel_version} xen_blkfront.sda_is_xvda=1 ro root=UUID=${uuid} selinux=0
  initrd /boot/${initrd_file}
GRUB_CONF
else
  echo "Unknown OS, exiting"
  exit 2
fi

run_in_chroot ${image_mount_point} "rm -f /boot/grub/menu.lst"
run_in_chroot ${image_mount_point} "ln -s ./grub.conf /boot/grub/menu.lst"

# Clean up bootloader stuff
umount ${image_mount_point}/tmp/grub/${stemcell_image_name}
rm -rf ${image_mount_point}/tmp/grub

# Unmount partition
for try in $(seq 0 9); do
  sleep $try
  echo "Unmounting ${image_mount_point} (try: ${try})"
  umount ${image_mount_point} || continue
  break
done

if mountpoint -q ${image_mount_point}; then
  echo "Could not unmount ${image_mount_point} after 10 tries"
  exit 1
fi

# Unmap partition
for try in $(seq 0 9); do
  sleep $try
  echo "Removing device mappings for ${disk_image} (try: ${try})"
  kpartx -dv ${device} && losetup --verbose --detach ${device} || continue
  break
done

if [ -b ${loopback_dev} ]; then
  echo "Could not remove device mapping at ${loopback_dev}"
  exit 1
fi
