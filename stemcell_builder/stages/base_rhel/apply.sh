#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash

mkdir -p $chroot/var/lib/rpm
rpm --root $chroot --initdb

case "${stemcell_operating_system_version}" in
  "7")
    release_package_url="/mnt/rhel/Packages/redhat-release-server-7.0-1.el7.x86_64.rpm"
    epel_package_url="http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm"
    ;;
  *)
    echo "Unknown RHEL version: ${stemcell_operating_system_version}"
    exit 1
    ;;
esac

if [ ! -f $release_package_url ]; then
  echo "Please mount the RHEL 7 install DVD at /mnt/rhel"
  exit 1
fi

rpm --root $chroot --force --nodeps --install ${release_package_url}

cp /etc/resolv.conf $chroot/etc/resolv.conf

dd if=/dev/urandom of=$chroot/var/lib/random-seed bs=512 count=1

unshare -m $SHELL <<INSTALL_YUM
  set -x

  mkdir -p /etc/pki
  mount --no-mtab --bind $chroot/etc/pki /etc/pki
  yum --installroot=$chroot -c /bosh/stemcell_builder/etc/custom_rhel_yum.conf --assumeyes install yum
INSTALL_YUM

if [ ! -d $chroot/mnt/rhel/Packages ]; then
  mkdir -p $chroot/mnt/rhel
  mount --bind /mnt/rhel $chroot/mnt/rhel
  add_on_exit "umount $chroot/mnt/rhel"
fi

run_in_chroot $chroot "
rpm --force --nodeps --install ${release_package_url}
rpm --force --nodeps --install ${epel_package_url}
rpm --rebuilddb
"

if [ ! -f $chroot/custom_rhel_yum.conf ]; then
  cp /bosh/stemcell_builder/etc/custom_rhel_yum.conf $chroot/
fi
run_in_chroot $chroot "yum -c /custom_rhel_yum.conf update --assumeyes"
run_in_chroot $chroot "yum -c /custom_rhel_yum.conf --verbose --assumeyes groupinstall Base"
run_in_chroot $chroot "yum -c /custom_rhel_yum.conf --verbose --assumeyes groupinstall 'Development Tools'"
run_in_chroot $chroot "yum -c /custom_rhel_yum.conf clean all"


# subscription-manager allows access to the Red Hat update server. It detects which repos
# it should allow access to based on the contents of 69.pem.
if [ ! -f /mnt/rhel/repodata/productid ]; then
  echo "Can't find Red Hat product certificate at /mnt/rhel/repodata/productid."
  echo "Please ensure you have mounted the RHEL 7 Server install DVD at /mnt/rhel."
  exit 1
fi

mkdir -p $chroot/etc/pki/product
cp /mnt/rhel/repodata/productid $chroot/etc/pki/product/69.pem

mount --bind /proc $chroot/proc
add_on_exit "umount $chroot/proc"

mount --bind /dev $chroot/dev
add_on_exit "umount $chroot/dev"

run_in_chroot $chroot "

if ! rct cat-cert /etc/pki/product/69.pem | grep -q rhel-7-server; then
  echo 'Product certificate from /mnt/rhel/repodata/productid is not for RHEL 7 server.'
  echo 'Please ensure you have mounted the RHEL 7 Server install DVD at /mnt/rhel.'
  exit 1
fi

subscription-manager register --username=${RHN_USERNAME} --password=${RHN_PASSWORD} --auto-attach
subscription-manager repos --enable=rhel-7-server-optional-rpms
"

touch ${chroot}/etc/sysconfig/network # must be present for network to be configured

# readahead-collector was pegging CPU on startup

echo 'READAHEAD_COLLECT="no"' >> ${chroot}/etc/sysconfig/readahead
echo 'READAHEAD_COLLECT_ON_RPM="no"' >> ${chroot}/etc/sysconfig/readahead

# Setting timezone
cp ${chroot}/usr/share/zoneinfo/UTC ${chroot}/etc/localtime

# Setting locale
echo "LANG=\"en_US.UTF-8\"" >> ${chroot}/etc/locale.conf
