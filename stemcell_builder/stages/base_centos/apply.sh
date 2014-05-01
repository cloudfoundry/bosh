#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

mkdir -p $chroot/var/lib/rpm
rpm --root $chroot --initdb
rpm --root $chroot --force --nodeps --install http://mirror.centos.org/centos/6/os/x86_64/Packages/centos-release-6-5.el6.centos.11.1.x86_64.rpm

cp /etc/resolv.conf $chroot/etc/resolv.conf

dd if=/dev/urandom of=$chroot/var/lib/random-seed bs=512 count=1

unshare -m $SHELL <<INSTALL_YUM
  set -x

  mkdir -p /etc/pki
  mount --no-mtab --bind $chroot/etc/pki /etc/pki
  yum --installroot=$chroot -c /bosh/stemcell_builder/etc/custom_yum.conf --assumeyes install yum
INSTALL_YUM

run_in_chroot $chroot "
rpm --force --nodeps --install http://mirror.centos.org/centos/6/os/x86_64/Packages/centos-release-6-5.el6.centos.11.1.x86_64.rpm
rpm --force --nodeps --install http://ftp.osuosl.org/pub/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm
rpm --rebuilddb
"

pkg_mgr groupinstall Base
pkg_mgr groupinstall 'Development Tools'

touch ${chroot}/etc/sysconfig/network # must be present for network to be configured

# readahead-collector was pegging CPU on startup

echo 'READAHEAD_COLLECT="no"' >> ${chroot}/etc/sysconfig/readahead
echo 'READAHEAD_COLLECT_ON_RPM="no"' >> ${chroot}/etc/sysconfig/readahead

# Setting timezone
cp ${chroot}/usr/share/zoneinfo/UTC ${chroot}/etc/localtime

# Setting locale
echo "LANG=\"en_US.UTF-8\"" >> ${chroot}/etc/sysconfig/i18n
