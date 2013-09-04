#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

mkdir -p $chroot/var/lib/rpm
rpm --root $chroot --rebuilddb
rpm --root $chroot --force --nodeps --install http://mirror.centos.org/centos/6/os/x86_64/Packages/centos-release-6-4.el6.centos.10.x86_64.rpm

cp /etc/resolv.conf $chroot/etc/resolv.conf

unshare -m $SHELL <<INSTALL_YUM
  set -x

  mkdir -p /etc/pki
  mount -obind $chroot/etc/pki /etc/pki
  yum --installroot=$chroot --assumeyes install yum
INSTALL_YUM

unshare -m $SHELL <<INSTALL_BASE_OS
  set -x

  mkdir -p $chroot/dev
  mount -obind /dev $chroot/dev
  mount -obind /dev/pts $chroot/dev/pts

  mkdir -p $chroot/proc
  mount -obind /proc $chroot/proc

  mkdir -p $chroot/sys
  mount -obind /sys $chroot/sys

  chroot $chroot rpm --force --nodeps --install http://mirror.centos.org/centos/6/os/x86_64/Packages/centos-release-6-4.el6.centos.10.x86_64.rpm
  chroot $chroot yum --assumeyes groupinstall Base
  chroot $chroot yum --assumeyes groupinstall 'Development Tools'
INSTALL_BASE_OS
