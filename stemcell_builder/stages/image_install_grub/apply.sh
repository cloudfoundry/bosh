#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

disk_image=${work}/${stemcell_image_name}
image_mount_point=${work}/mnt

## unmap the loop device in case it's already mapped
#umount ${image_mount_point}/proc || true
#umount ${image_mount_point}/sys || true
#umount ${image_mount_point} || true
#losetup -j ${disk_image} | cut -d ':' -f 1 | xargs --no-run-if-empty losetup -d
kpartx -dv ${disk_image}

# note: if the above kpartx command fails, it's probably because the loopback device needs to be unmapped.
# in that case, try this: sudo dmsetup remove loop0p1

# Map partition in image to loopback
device=$(losetup --show --find ${disk_image})
add_on_exit "losetup --verbose --detach ${device}"

device_partition=$(kpartx -av ${device} | grep "^add" | cut -d" " -f3)
add_on_exit "kpartx -dv ${device}"

loopback_dev="/dev/mapper/${device_partition}"

# Mount partition
mkdir -p ${image_mount_point}

mount ${loopback_dev} ${image_mount_point}
add_on_exit "umount ${image_mount_point}"

# == Guide to variables in this script (all paths are defined relative to the real root dir, not the chroot)

# work: the base working directory outside the chroot
#      eg: /mnt/stemcells/aws/xen/centos/work/work
# disk_image: path to the stemcell disk image
#      eg: /mnt/stemcells/aws/xen/centos/work/work/aws-xen-centos.raw
# device: path to the loopback devide mapped to the entire disk image
#      eg: /dev/loop0
# loopback_dev: device node mapped to the main partition in disk_image
#      eg: /dev/mapper/loop0p1
# image_mount_point: place where loopback_dev is mounted as a filesystem
#      eg: /mnt/stemcells/aws/xen/centos/work/work/mnt

# Install bootloader
if [ -x ${image_mount_point}/usr/sbin/grub2-install ] # GRUB 2
then

  # GRUB 2 needs to operate on the loopback block device for the whole FS image, so we map it into the chroot environment
  touch ${image_mount_point}${device}
  mount --bind ${device} ${image_mount_point}${device}
  add_on_exit "umount ${image_mount_point}${device}"

  mkdir -p `dirname ${image_mount_point}${loopback_dev}`
  touch ${image_mount_point}${loopback_dev}
  mount --bind ${loopback_dev} ${image_mount_point}${loopback_dev}
  add_on_exit "umount ${image_mount_point}${loopback_dev}"

  # GRUB 2 needs /sys and /proc to do its job
  mount -t proc none ${image_mount_point}/proc
  add_on_exit "umount ${image_mount_point}/proc"
  
  mount -t sysfs none ${image_mount_point}/sys
  add_on_exit "umount ${image_mount_point}/sys"
  
  echo "(hd0) ${device}" > ${image_mount_point}/device.map

  # install bootsector into disk image file
  run_in_chroot ${image_mount_point} "grub2-install -v --no-floppy --grub-mkdevicemap=/device.map ${device}"

  cat >${image_mount_point}/etc/default/grub <<EOF
GRUB_CMDLINE_LINUX="vconsole.keymap=us net.ifnames=0 crashkernel=auto selinux=0 plymouth.enable=0"
EOF

  # assemble config file that is read by grub2 at boot time
  run_in_chroot ${image_mount_point} "GRUB_DISABLE_RECOVERY=true grub2-mkconfig -o /boot/grub2/grub.cfg"

  rm ${image_mount_point}/device.map
else # Classic GRUB

  mkdir -p ${image_mount_point}/tmp/grub
  add_on_exit "rm -rf ${image_mount_point}/tmp/grub"

  touch ${image_mount_point}/tmp/grub/${stemcell_image_name}

  mount --bind $work/${stemcell_image_name} ${image_mount_point}/tmp/grub/${stemcell_image_name}
  add_on_exit "umount ${image_mount_point}/tmp/grub/${stemcell_image_name}"

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
fi # end of GRUB and GRUB 2 bootsector installation


# Figure out uuid of partition
uuid=$(blkid -c /dev/null -sUUID -ovalue ${loopback_dev})

kernel_version=$(basename $(ls ${image_mount_point}/boot/vmlinuz-* |tail -1) |cut -f2-8 -d'-')

if [ -f ${image_mount_point}/etc/debian_version ] # Ubuntu
then
  initrd_file="initrd.img-${kernel_version}"
  os_name=$(source ${image_mount_point}/etc/lsb-release ; echo -n ${DISTRIB_DESCRIPTION})
elif [ -f ${image_mount_point}/etc/redhat-release ] # Centos or RHEL
then
  initrd_file="initramfs-${kernel_version}.img"
  os_name=$(cat ${image_mount_point}/etc/redhat-release)
  cat > ${image_mount_point}/etc/fstab <<FSTAB
# /etc/fstab Created by BOSH Stemcell Builder
UUID=${uuid} / ext4 defaults 1 1
FSTAB
elif [ -f ${image_mount_point}/etc/photon-release ] # Photon
then
  initrd_file="initramfs-${kernel_version}.img"
  os_name=$(cat ${image_mount_point}/etc/photon-release)
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
  kernel /boot/vmlinuz-${kernel_version} ro root=UUID=${uuid} selinux=0 cgroup_enable=memory swapaccount=1 console=tty0 console=ttyS0,115200n8
  initrd /boot/${initrd_file}
GRUB_CONF

elif [ -f ${image_mount_point}/etc/redhat-release ] # Centos or RHEL
then
  cat > ${image_mount_point}/boot/grub/grub.conf <<GRUB_CONF
default=0
timeout=1
title ${os_name} (${kernel_version})
  root (hd0,0)
  kernel /boot/vmlinuz-${kernel_version} ro root=UUID=${uuid} net.ifnames=0 plymouth.enable=0 selinux=0 console=tty0 console=ttyS0,115200n8
  initrd /boot/${initrd_file}
GRUB_CONF

elif [ -f ${image_mount_point}/etc/photon-release ] # Photon
then
  cat > ${image_mount_point}/boot/grub/grub.conf <<GRUB_CONF
default=0
timeout=1
title ${os_name} (${kernel_version})
  root (hd0,0)
  kernel /boot/vmlinuz-${kernel_version} ro root=UUID=${uuid} net.ifnames=0 plymouth.enable=0 selinux=0 console=tty0 console=ttyS0,115200n8
  initrd /boot/${initrd_file}
GRUB_CONF

else
  echo "Unknown OS, exiting"
  exit 2
fi

run_in_chroot ${image_mount_point} "rm -f /boot/grub/menu.lst"
run_in_chroot ${image_mount_point} "ln -s ./grub.conf /boot/grub/menu.lst"
