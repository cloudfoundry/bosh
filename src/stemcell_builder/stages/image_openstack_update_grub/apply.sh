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

# Regenerate menu.lst
run_in_chroot ${image_mount_point} "
sed -i -e 's/^# defoptions=.*/# defoptions=console=hvc0/' /boot/grub/menu.lst # Pass virtual console device to kernel
update-grub
rm -f /boot/grub/menu.lst~
"

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
