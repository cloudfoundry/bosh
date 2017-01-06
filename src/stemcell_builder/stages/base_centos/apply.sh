#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash

mkdir -p $chroot/var/lib/rpm
rpm --root $chroot --initdb
case "${stemcell_operating_system_version}" in
  "7")
    centos_release_package_url="http://mirror.centos.org/centos/7/os/x86_64/Packages/centos-release-7-3.1611.el7.centos.x86_64.rpm"
    epel_package_url="https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
    ;;
  *)
    echo "Unknown centos version: ${stemcell_operating_system_version}"
    exit 1
    ;;
esac

rpm --import $(dirname $0)/assets/RPM-GPG-KEY-CentOS-7
curl -o centos-release.rpm ${centos_release_package_url}
rpm -K centos-release.rpm

rpm --root $chroot --force --nodeps --install centos-release.rpm

cp $(dirname $0)/assets/RPM-GPG-KEY-EPEL-7 ${chroot}/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
cp /etc/resolv.conf $chroot/etc/resolv.conf

dd if=/dev/urandom of=$chroot/var/lib/random-seed bs=512 count=1

unshare -m $SHELL <<INSTALL_YUM
  set -x

  mkdir -p /etc/pki
  mount --no-mtab --bind $chroot/etc/pki /etc/pki
  yum --installroot=$chroot -c $base_dir/etc/custom_yum.conf --assumeyes install yum
INSTALL_YUM

run_in_chroot $chroot "
curl -o centos-release.rpm ${centos_release_package_url}
curl -o epel-package.rpm ${epel_package_url}

rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7

rpm -K centos-release.rpm
rpm -K epel-package.rpm

rpm --force --nodeps --install centos-release.rpm
rpm --force --nodeps --install epel-package.rpm

rpm --rebuilddb
"

pkg_mgr install kernel
pkg_mgr groupinstall Base
pkg_mgr groupinstall 'Development Tools'

touch ${chroot}/etc/sysconfig/network # must be present for network to be configured

# readahead-collector was pegging CPU on startup

echo 'READAHEAD_COLLECT="no"' >> ${chroot}/etc/sysconfig/readahead
echo 'READAHEAD_COLLECT_ON_RPM="no"' >> ${chroot}/etc/sysconfig/readahead

# Setting locale
case "${stemcell_operating_system_version}" in
  "7")
    locale_file=/etc/locale.conf
    ;;
  *)
    echo "Unknown CentOS release: ${stemcell_operating_system_version}"
    exit 1
    ;;
esac

echo "LANG=\"en_US.UTF-8\"" >> ${chroot}/${locale_file}
