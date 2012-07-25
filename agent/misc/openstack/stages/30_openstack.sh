#!/bin/bash
#
# Copyright (c) 2009-2012 VMware, Inc.

srcdir=$(dirname $(readlink -nf $0))
basedir=$(dirname $(readlink -nf ${srcdir/..}))
libdir=$basedir/lib
skeleton=$basedir/skeleton

. ${libdir}/helpers.sh

if [ $# -ne 2 ]
then
  echo "Usage: env `basename $0` [chroot_target] [lib_dir]"
  exit 1
fi

if [ `id -u` -ne "0" ]
then
  echo "Sorry, you need to be root"
  exit 1
fi

target=$1
lib_dir=$2

if [ ! -d $lib_dir ]
then
  echo "Instance directory $lib_dir doesn't exist or isn't a directory"
  exit 1
fi

# Set up mounts
mount --bind /dev $target/dev
mount --bind /dev/pts $target/dev/pts
chroot $target mount -t proc proc /proc
add_on_exit "umount ${target}/proc $target/dev/pts $target/dev"

# Prevent daemons from starting
disable_daemon_startup $target $skeleton
add_on_exit "enable_daemon_startup $target"

# openstack specific packages(grub is not actually installed, we just need /boot/grub/menu.lst for pv-grub)
export DEBIAN_FRONTEND=noninteractive
run_in_chroot $target "apt-get install -y --force-yes --no-install-recommends grub-pc grub-legacy-ec2"

mkdir -p $target/var/vcap/bosh/src
cp -r $lib_dir/openstack $target/var/vcap/bosh/src/

chroot $target /var/vcap/bosh/src/openstack/configure_openstack.sh