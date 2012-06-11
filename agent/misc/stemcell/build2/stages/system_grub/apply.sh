#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Install grub
apt_get install grub
rsync -a $chroot/usr/lib/grub/x86*/ $chroot/boot/grub/

# When a kernel is installed, update-grub is run per /etc/kernel-img.conf.
# It complains when /boot/grub/menu.lst doesn't exist, so create it.
touch $chroot/boot/grub/menu.lst
