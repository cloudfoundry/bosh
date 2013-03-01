#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Define variables
mirror=

# Use ISO as mirror
if [ ! -z "${UBUNTU_ISO:-}" ]
then
  iso_mount_path=`mktemp -d`
  echo "Mounting iso from $UBUNTU_ISO at $iso_mount_path"
  mount -o loop -t iso9660 $UBUNTU_ISO $iso_mount_path
  add_on_exit "umount $iso_mount_path"
  mirror="file://$iso_mount_path"
fi

# Use specified mirror
if [ ! -z "${UBUNTU_MIRROR:-}" ]
then
  mirror=$UBUNTU_MIRROR
fi

# Bootstrap the base system
echo "Running debootstrap"
debootstrap --arch=$base_debootstrap_arch $base_debootstrap_suite $chroot $mirror

# Shady work around vmbuilder in combination with ubuntu iso cache corrupting
# the debian list caches. There is a discussion in:
# https://bugs.launchpad.net/ubuntu/+source/update-manager/+bug/24061
rm -f $chroot/var/lib/apt/lists/{archive,security,lock}*
