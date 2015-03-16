#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Install grub or grub2 (check existence of classic grub package first because Ubuntu Trusty has a transitional grub2 dummy package)

if pkg_exists grub; then
  pkg_mgr install grub
elif pkg_exists grub2; then
  pkg_mgr install grub2
else
  echo "Can't find grub or grub2 package to install"
  exit 2
fi

if [ -d $chroot/usr/lib/grub/x86* ] # classic GRUB on Ubuntu
then

  rsync -a $chroot/usr/lib/grub/x86*/ $chroot/boot/grub/

elif [ -d $chroot/usr/share/grub/x86* ] # classic GRUB on CentOS 6.5
then

  rsync -a $chroot/usr/share/grub/x86*/ $chroot/boot/grub/

elif [ -d $chroot/etc/grub.d ] # GRUB 2 on CentOS 7 or Ubuntu
then

  echo "Found grub2; leaving config files where they are"

else

  echo "Can't find GRUB or GRUB 2 config files, exiting"
  exit 2

fi

# When a kernel is installed, update-grub is run per /etc/kernel-img.conf.
# It complains when /boot/grub/menu.lst doesn't exist, so create it.
touch $chroot/boot/grub/menu.lst
