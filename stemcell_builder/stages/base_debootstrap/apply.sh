#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Older debootstrap leaves udev daemon child process when building trusty release
# https://bugs.launchpad.net/ubuntu/+source/debootstrap/+bug/1182540
# The issue was fixed in 1.0.52
downloaded_file=`mktemp`

# Install debootstrap
if is_ppc64le; then
  wget "http://archive.ubuntu.com/ubuntu/pool/main/d/debootstrap/debootstrap_1.0.67_all.deb" -qO $downloaded_file && \
    echo "0a12e0a2bbff185d47711a716b1f2734856100e8784361203e834fed0cffa51b  $downloaded_file" | shasum -a 256 -c -
else
  wget "http://archive.ubuntu.com/ubuntu/pool/main/d/debootstrap/debootstrap_1.0.59_all.deb" -qO $downloaded_file && \
    echo "1df1b167fed24eb2cae0bcc0ba6d5357f6a40fe0a8aaa6bfe828c7a007413f65  $downloaded_file" | shasum -a 256 -c -
fi

dpkg -i $downloaded_file
rm $downloaded_file

# Bootstrap the base system
echo "Running debootstrap"
debootstrap --arch=$base_debootstrap_arch $base_debootstrap_suite $chroot ""

# See https://bugs.launchpad.net/ubuntu/+source/update-manager/+bug/24061
rm -f $chroot/var/lib/apt/lists/{archive,security,lock}*

# Copy over some other system assets
# Networking...
cp $assets_dir/etc/hosts $chroot/etc/hosts

# Timezone
cp $assets_dir/etc/timezone $chroot/etc/timezone

run_in_chroot $chroot "dpkg-reconfigure -fnoninteractive -pcritical tzdata"

# Locale
cp $assets_dir/etc/default/locale $chroot/etc/default/locale
run_in_chroot $chroot "locale-gen en_US.UTF-8"
run_in_chroot $chroot "dpkg-reconfigure locales"
