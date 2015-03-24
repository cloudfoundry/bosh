#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

disk_image=${work}/${stemcell_image_name}

# Reserve the first 63 sectors for grub
part_offset=63s
part_size=$((${image_create_disk_size} - 1))

dd if=/dev/null of=${disk_image} bs=1M seek=${image_create_disk_size} 2> /dev/null
parted --script ${disk_image} mklabel msdos
parted --script ${disk_image} mkpart primary ext2 $part_offset $part_size

# unmap the loop device in case it's already mapped
kpartx -dv ${disk_image}

# Map partition in image to loopback
device=$(losetup --show --find ${disk_image})
add_on_exit "losetup --verbose --detach ${device}"

device_partition=$(kpartx -av ${device} | grep "^add" | cut -d" " -f3)
add_on_exit "kpartx -dv ${device}"

loopback_dev="/dev/mapper/${device_partition}"

# Format partition
mkfs.ext4 ${loopback_dev}

# Mount partition
image_mount_point=${work}/mnt
mkdir -p ${image_mount_point}
mount ${loopback_dev} ${image_mount_point}
add_on_exit "umount ${image_mount_point}"

# Copy root
time rsync -aHA $chroot/ ${image_mount_point}
