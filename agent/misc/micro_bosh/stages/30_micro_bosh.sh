#!/bin/bash
#
# Copyright (c) 2009-2012 VMware, Inc.

srcdir=$(dirname $(readlink -nf $0))
basedir=$(dirname $(readlink -nf ${srcdir/..}))
libdir=$basedir/lib
skeleton=$basedir/skeleton

. ${libdir}/helpers.sh

if [ $# -ne 4 ]
then
  echo "Usage: env `basename $0` [chroot_target] [instance_dir] [package_dir] [infrastructure]"
  exit 1
fi

if [ `id -u` -ne "0" ]
then
  echo "Sorry, you need to be root"
  exit 1
fi

target=$1
instance_dir=$2
package_dir=$3
infrastructure=$4

if [ ! -d $instance_dir ]
then
  echo "Instance directory $instance_dir doesn't exist or isn't a directory"
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

# micro bosh specific packages
run_in_chroot $target "apt-get install -y --force-yes --no-install-recommends libpq-dev genisoimage"

mkdir -p $target/var/vcap/bosh/src
cp -r $instance_dir/micro_bosh $target/var/vcap/bosh/src
cp -r $instance_dir/micro_bosh_release $target/var/vcap/bosh/src

chroot $target /var/vcap/bosh/src/micro_bosh/lib/configure_micro_bosh.sh $infrastructure

# Copy the generated apply spec to packaging directory
cp $target/var/vcap/micro/apply_spec.yml $package_dir
