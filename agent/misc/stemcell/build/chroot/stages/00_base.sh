#!/bin/bash

set -e

srcdir=$(dirname $(readlink -nf $0))
basedir=$(dirname $(readlink -nf ${srcdir/..}))
libdir=$basedir/lib
skeleton=$basedir/skeleton

release="lucid"
arch="amd64"
debs='build-essential libssl-dev lsof \
strace bind9-host dnsutils tcpdump iputils-arping \
curl wget libcurl3 libcurl3-dev bison libreadline5-dev \
libxml2 libxml2-dev libxslt1.1 libxslt1-dev zip unzip \
nfs-common flex psmisc apparmor-utils iptables sysstat \
quota quotatool traceroute'

. ${libdir}/helpers.sh

if [ $# -lt 1 ]
then
  echo "Usage: `basename $0` [chroot_target] [ubuntu iso]"
  exit 1
fi

if [ `id -u` -ne "0" ]
then
  echo "Sorry, you need to be root"
  exit 1
fi

target=$1
ubuntu_iso=$2

# Mount the iso to be used as a cache for debootstrap
if [ ! -z $ubuntu_iso ]
then
  iso_mount_path=`mktemp -d`
  echo "Mounting iso from $ubuntu_iso at $iso_mount_path"
  mount -o loop -t iso9660 ${ubuntu_iso} ${iso_mount_path}
  add_on_exit "umount $iso_mount_path"
  iso_cache="file://$iso_mount_path"
fi

# Bootstrap the base system
echo "Running debootstrap"
debootstrap --arch=$arch $release $target $iso_cache

# Update apt
echo "Updating apt"
cp $skeleton/etc/apt/sources.list $target/etc/apt/sources.list
chroot $target apt-get update

# Prevent daemons from starting
disable_daemon_startup $target $skeleton
add_on_exit "enable_daemon_startup $target"

# Set up mounts
mount --bind /dev $target/dev
mount --bind /dev/pts $target/dev/pts
chroot $target mount -t proc proc /proc
add_on_exit "umount ${target}/proc $target/dev/pts $target/dev"

# Networking...
cp $skeleton/etc/hosts $target/etc/hosts

# Timezone
cp $skeleton/etc/timezone $target/etc/timezone
run_in_chroot $target "dpkg-reconfigure -fnoninteractive -pcritical tzdata"

# Locale
cp $skeleton/etc/default/locale $target/etc/default/locale
run_in_chroot $target "locale-gen en_US.UTF-8
dpkg-reconfigure -fnoninteractive -pcritical libc6
dpkg-reconfigure -fnoninteractive -pcritical locales
"
# Firstboot script
cp $skeleton/etc/rc.local $target/etc/rc.local
cp $skeleton/root/firstboot.sh $target/root/firstboot.sh
chmod 0755 $target/root/firstboot.sh

# Update packages
run_in_chroot $target "apt-get -y --force-yes dist-upgrade"
cp $skeleton/etc/apt/sources.list $target/etc/apt/sources.list
run_in_chroot $target 'apt-get update'

# Shady work around vmbuilder in combination with ubuntu iso cache corrupting
# the debian list caches. There is s discussion in:
#  https://bugs.launchpad.net/ubuntu/+source/update-manager/+bug/24061
rm $target/var/lib/apt/lists/{archive,security,lock}*
run_in_chroot $target 'apt-get update'

# Install base debs needed by both the warden and bosh
run_in_chroot $target "apt-get install -y --force-yes --no-install-recommends $debs"

# Woo, done. Clean up.
run_in_chroot $target "apt-get clean"
