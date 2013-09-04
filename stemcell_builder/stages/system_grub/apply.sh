#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Install grub
pkg_mgr install grub

if [ -d $chroot/usr/lib/grub ] # Ubuntu
then
  rsync -a $chroot/usr/lib/grub/x86*/ $chroot/boot/grub/
fi

if [ -d $chroot/usr/share/grub ] # CentOS
then
  rsync -a $chroot/usr/share/grub/x86*/ $chroot/boot/grub/
fi

# When a kernel is installed, update-grub is run per /etc/kernel-img.conf.
# It complains when /boot/grub/menu.lst doesn't exist, so create it.
touch $chroot/boot/grub/menu.lst
