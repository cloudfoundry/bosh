#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

mkdir -p $chroot/var/lib/rpm
rpm --root $chroot --initdb
rpm --root $chroot --force --nodeps --install http://mirror.centos.org/centos/6/os/x86_64/Packages/centos-release-6-4.el6.centos.10.x86_64.rpm

cp /etc/resolv.conf $chroot/etc/resolv.conf

unshare -m $SHELL <<INSTALL_YUM
  set -x

  mkdir -p /etc/pki
  mount --no-mtab --bind $chroot/etc/pki /etc/pki
  yum --installroot=$chroot --assumeyes install yum
INSTALL_YUM

run_in_chroot $chroot "
rpm --force --nodeps --install http://mirror.centos.org/centos/6/os/x86_64/Packages/centos-release-6-4.el6.centos.10.x86_64.rpm
rpm --force --nodeps --install http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum --assumeyes groupinstall Base
yum --assumeyes groupinstall 'Development Tools'
"

touch ${chroot}/etc/sysconfig/network # must be present for network to be configured
