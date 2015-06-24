#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash

wget \
  -O /tmp/ixgbevf-2.16.1.tar.gz \
  'http://iweb.dl.sourceforge.net/project/e1000/ixgbevf%20stable/2.16.1/ixgbevf-2.16.1.tar.gz'

[ 'cf2164ac87de1c9e9c8790b1391a9916715e701c' == $( shasum /tmp/ixgbevf-2.16.1.tar.gz | awk '{ print $1 }' ) ]

mkdir $chroot/usr/src/ixgbevf-2.16.1

tar -xzf /tmp/ixgbevf-2.16.1.tar.gz \
  -C $chroot/usr/src/ixgbevf-2.16.1 \
  --strip-components=1

cp $assets_dir/usr/src/ixgbevf-2.16.1/dkms.conf $chroot/usr/src/ixgbevf-2.16.1/dkms.conf

pkg_mgr install dkms

kernelver=$( ls $chroot/lib/modules )
run_in_chroot $chroot "dkms -k ${kernelver} add -m ixgbevf -v 2.16.1"
run_in_chroot $chroot "dkms -k ${kernelver} build -m ixgbevf -v 2.16.1"
run_in_chroot $chroot "dkms -k ${kernelver} install -m ixgbevf -v 2.16.1"
run_in_chroot $chroot "update-initramfs -c -k all"
