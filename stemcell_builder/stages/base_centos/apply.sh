#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash

mkdir -p $chroot/var/lib/rpm
rpm --root $chroot --initdb
case "${stemcell_operating_system_version}" in
  "6")
    centos_release_package_url="http://mirror.centos.org/centos/6/os/x86_64/Packages/centos-release-6-6.el6.centos.12.2.x86_64.rpm"
    epel_package_url="http://ftp.osuosl.org/pub/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm"
    ;;
  "7")
    centos_release_package_url="http://mirror.centos.org/centos/7/os/x86_64/Packages/centos-release-7-1.1503.el7.centos.2.8.x86_64.rpm"
    epel_package_url="http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm"
    ;;
  *)
    echo "Unknown centos version: ${stemcell_operating_system_version}"
    exit 1
    ;;
esac

rpm --root $chroot --force --nodeps --install ${centos_release_package_url}

cp /etc/resolv.conf $chroot/etc/resolv.conf

dd if=/dev/urandom of=$chroot/var/lib/random-seed bs=512 count=1

unshare -m $SHELL <<INSTALL_YUM
  set -x

  mkdir -p /etc/pki
  mount --no-mtab --bind $chroot/etc/pki /etc/pki
  yum --installroot=$chroot -c /bosh/stemcell_builder/etc/custom_yum.conf --assumeyes install yum
INSTALL_YUM

run_in_chroot $chroot "
rpm --force --nodeps --install ${centos_release_package_url}
rpm --force --nodeps --install ${epel_package_url}
rpm --rebuilddb
"

pkg_mgr install kernel
pkg_mgr groupinstall Base
pkg_mgr groupinstall 'Development Tools'

touch ${chroot}/etc/sysconfig/network # must be present for network to be configured

# readahead-collector was pegging CPU on startup

echo 'READAHEAD_COLLECT="no"' >> ${chroot}/etc/sysconfig/readahead
echo 'READAHEAD_COLLECT_ON_RPM="no"' >> ${chroot}/etc/sysconfig/readahead

# Setting timezone
cp ${chroot}/usr/share/zoneinfo/UTC ${chroot}/etc/localtime

# Setting locale
case "${stemcell_operating_system_version}" in
  "6")
    locale_file=/etc/sysconfig/i18n
    ;;
  "7")
    locale_file=/etc/locale.conf
    ;;
  *)
    echo "Unknown CentOS release: ${stemcell_operating_system_version}"
    exit 1
    ;;
esac

echo "LANG=\"en_US.UTF-8\"" >> ${chroot}/${locale_file}
