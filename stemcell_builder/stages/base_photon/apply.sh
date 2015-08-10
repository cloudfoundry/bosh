#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash

mkdir -p $chroot/var/lib/rpm
rpm --root $chroot --initdb

release_package_url="$(find /mnt/photon/ -name 'photon-release*.rpm' -print)"
if mountpoint -q /mnt/photon && [ -n $release_package_url ] ;
then
   echo "Photon ISO is mounted."
else
   echo "Photon ISO is not mounted. Please mount the Photon ISO at /mnt/photon"
   exit 1
fi

unshare -m $SHELL <<INSTALL_YUM
  set -x
  mkdir -p /etc/pki
  yum --installroot=$chroot -c /bosh/stemcell_builder/etc/custom_photon_yum.conf --assumeyes install yum
INSTALL_YUM

if [ ! -d $chroot/mnt/photon ]; then
  mkdir -p $chroot/mnt/photon
  mount --bind /mnt/photon $chroot/mnt/photon
  add_on_exit "umount $chroot/mnt/photon"
fi

cp /etc/resolv.conf $chroot/etc/resolv.conf
dd if=/dev/urandom of=$chroot/var/lib/random-seed bs=512 count=1

if [ ! -f $chroot/custom_rhel_yum.conf ]; then
  cp /bosh/stemcell_builder/etc/custom_photon_yum.conf $chroot/
fi


run_in_chroot $chroot "yum -c /custom_photon_yum.conf update --assumeyes"
run_in_chroot $chroot "yum -c /custom_photon_yum.conf --verbose --assumeyes install photon-release"
run_in_chroot $chroot "yum -c /custom_photon_yum.conf --verbose --assumeyes install linux-api-headers glibc glibc-devel glibc-lang zlib zlib-devel file binutils binutils-devel gmp gmp-devel mpfr mpfr-devel mpc coreutils flex bison bindutils sudo e2fsprogs elfutils shadow cracklib Linux-PAM findutils diffutils sed grep tar gawk which make patch gzip openssl openssh wget vim tdnf yum curl grub2 tzdata readline-devel ncurses-devel cmake bzip2-devel cdrkit ruby logrotate ntp"
run_in_chroot $chroot "yum -c /custom_photon_yum.conf --verbose --assumeyes install linux dracut dkms linux-dev"
run_in_chroot $chroot "yum -c /custom_photon_yum.conf --verbose --assumeyes install systemd rsyslog cronie gcc kpartx NetworkManager pkg-config ncurses bash bzip2 cracklib-dicts shadow procps-ng iana-etc readline coreutils bc libtool inetutils findutils xz iproute2 util-linux ca-certificates iptables attr libcap expat dbus sqlite-autoconf nspr nss rpm libffi gdbm python2 python2-libs pcre glib libxml2 photon-release cpio gzip db libsolv libgpg-error hawkey libassuan gpgme librepo tdnf libdnet xerces-c xml-security-c libmspack  krb5 e2fsprogs-devel kmod dhcp-client initscripts libtirpc lsof runit"

run_in_chroot $chroot "yum -c /custom_photon_yum.conf clean all"
run_in_chroot $chroot "touch /etc/machine-id"


touch ${chroot}/etc/sysconfig/network # must be present for network to be configured

# Setting timezone
cp ${chroot}/usr/share/zoneinfo/UTC ${chroot}/etc/localtime

#generating default locales
run_in_chroot $chroot "/usr/sbin/locale-gen.sh"
# Setting locale
echo "LANG=\"en_US.UTF-8\"" >> ${chroot}/etc/locale.conf

cat >> ${chroot}/etc/login.defs <<-EOF
USERGROUPS_ENAB yes
EOF

run_in_chroot ${chroot} "systemctl disable systemd-networkd"
run_in_chroot ${chroot} "systemctl enable runit"
run_in_chroot ${chroot} "systemctl enable NetworkManager"

#Adding system-release file as Specinfra ruby gem can identify Photon as RPM Based Linux Distro  
run_in_chroot ${chroot} "touch /etc/system-release"
kernelver=$( ls $chroot/lib/modules )
run_in_chroot ${chroot} "dracut --force --kver ${kernelver}"




