#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Remove persistent device names so that eth0 comes up as eth0
rm -fr $chroot/etc/udev/rules.d/70-persistent-net.rules

if [ -e "$chroot/etc/network/interfaces" ]; then # ubuntu
  echo -n "localhost" > $chroot/etc/hostname

  cat >> $chroot/etc/network/interfaces <<EOS
auto lo
iface lo inet loopback
EOS

elif [ -e "$chroot/etc/sysconfig/network" ]; then # centos
  cat >> $chroot/etc/sysconfig/network <<EOS
NETWORKING=yes
NETWORKING_IPV6=no
HOSTNAME=localhost.localdomain
NOZEROCONF=yes
EOS

  cat >> $chroot/etc/NetworkManager/NetworkManager.conf <<EOS
[main]
plugins=ifcfg-rh
no-auto-default=*
EOS

fi
