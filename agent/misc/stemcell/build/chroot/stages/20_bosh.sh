#!/bin/bash

srcdir=$(dirname $(readlink -nf $0))
basedir=$(dirname $(readlink -nf ${srcdir/..}))
stemcelldir=$(dirname $(readlink -nf "${srcdir}/.."))
libdir=$basedir/lib
skeleton=$basedir/skeleton
kernel="lts-backport-natty"

. ${libdir}/helpers.sh

if [ $# -ne 2 ]
then
  echo "Usage: env `basename $0` [chroot_target] [instance_dir]"
  exit 1
fi

if [ `id -u` -ne "0" ]
then
  echo "Sorry, you need to be root"
  exit 1
fi

target=$1
instance_dir=$2

if [ ! -d $instance_dir ]
then
  echo "Instance directory $instance_dir doesn't exist or isn't a directory"
  exit 1
fi

debs='openssh-server scsitools tshark mg htop module-assistant debhelper rsync runit'

# Disable daemon startup
disable_daemon_startup $target $skeleton
add_on_exit "enable_daemon_startup $target"

# Set up mounts
mount --bind /dev $target/dev
mount --bind /dev/pts $target/dev/pts
chroot $target mount -t proc proc /proc
add_on_exit "umount ${target}/proc $target/dev/pts $target/dev"

# Custom kernel
echo "Installing kernel: $kernel"
run_in_chroot $target "env DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes --no-install-recommends linux-image-server-${kernel} linux-headers-server-${kernel}"

# BOSH Specific configuration
mkdir -p $target/var/vcap/bosh
cp -r $instance_dir $target/var/vcap/bosh/src
cp $libdir/configure_bosh.sh $target/var/vcap/bosh/src
chmod 0755 $target/var/vcap/bosh/src

# open-vm-tools needed to be backported to work with the 2.6.38 kernel
# https://bugs.launchpad.net/ubuntu/+source/open-vm-tools/+bug/746152
run_in_chroot $target "dpkg -i /var/vcap/bosh/src/open-vm-*.deb"
# Fix missing dependencies for the open-vm debs
run_in_chroot $target "apt-get -f -y --force-yes --no-install-recommends install"

# Install packages
run_in_chroot $target "apt-get install -y --force-yes --no-install-recommends $debs"
run_in_chroot $target "apt-get clean"

chroot $target /var/vcap/bosh/src/configure_bosh.sh

# Clean up
run_in_chroot $target "apt-get clean"
