#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

mount --bind /sys $chroot/sys
add_on_exit "umount $chroot/sys"

cat > $chroot/etc/apt/sources.list <<EOS
deb http://archive.ubuntu.com/ubuntu $DISTRIB_CODENAME main universe multiverse
deb http://archive.ubuntu.com/ubuntu $DISTRIB_CODENAME-updates main universe multiverse
deb http://security.ubuntu.com/ubuntu $DISTRIB_CODENAME-security main universe multiverse
EOS

# Upgrade upstart first, to prevent it from messing up our stubs and starting daemons anyway
pkg_mgr install upstart
run_in_chroot $chroot "apt-get download libudev1"
run_in_chroot $chroot "apt-get download udev"
run_in_chroot $chroot "dpkg -i --force-confmiss libudev1*.deb"
run_in_chroot $chroot "dpkg -i --force-confmiss udev_*.deb"
pkg_mgr dist-upgrade
