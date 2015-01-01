#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Install grub
if [ `uname -m` == "ppc64le" ]; then 
  # ppc64le uses grub2
  pkg_mgr install grub2
else
  pkg_mgr install grub
fi

if [ -f $chroot/etc/debian_version ] # Ubuntu
then

  if [ `uname -m` == "ppc64le" ]; then 
    rsync -a $chroot/usr/lib/grub/powerpc*/ $chroot/boot/grub/
  else
    rsync -a $chroot/usr/lib/grub/x86*/ $chroot/boot/grub/
  fi

elif [ -f $chroot/etc/centos-release ] # CentOS
then

  rsync -a $chroot/usr/share/grub/x86*/ $chroot/boot/grub/

else

  echo "Unknown OS, exiting"
  exit 2

fi

# When a kernel is installed, update-grub is run per /etc/kernel-img.conf.
# It complains when /boot/grub/menu.lst doesn't exist, so create it.
touch $chroot/boot/grub/menu.lst
