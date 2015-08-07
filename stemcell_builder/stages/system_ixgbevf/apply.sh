#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash

mkdir $chroot/usr/src/ixgbevf-2.16.1

tar -xzf $assets_dir/ixgbevf-2.16.1.tar.gz \
  -C $chroot/usr/src/ixgbevf-2.16.1 \
  --strip-components=1

cp $assets_dir/usr/src/ixgbevf-2.16.1/dkms.conf $chroot/usr/src/ixgbevf-2.16.1/dkms.conf

pkg_mgr install dkms

kernelver=$( ls $chroot/lib/modules )
run_in_chroot $chroot "dkms -k ${kernelver} add -m ixgbevf -v 2.16.1"
run_in_chroot $chroot "dkms -k ${kernelver} build -m ixgbevf -v 2.16.1"
run_in_chroot $chroot "dkms -k ${kernelver} install -m ixgbevf -v 2.16.1"


if [ -f ${chroot}/etc/debian_version ] # Ubuntu
then
  run_in_chroot $chroot "update-initramfs -c -k all"
elif [ -f ${chroot}/etc/redhat-release ] # Centos or RHEL
then
  run_in_chroot $chroot "dracut --force --kver ${kernelver}"
elif [ -f ${chroot}/etc/photon-release ] # Photon
then
  run_in_chroot $chroot "dracut --force --kver ${kernelver}"
else
  echo "Unknown OS, exiting"
  exit 2
fi
