#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Remove persistent device names so that eth0 comes up as eth0
rm -fr $chroot/etc/udev/rules.d/70-persistent-net.rules

# Context on the need to replace the hostname is here:
# https://github.com/cloudfoundry/bosh/issues/1399
echo -n "bosh-stemcell" > $chroot/etc/hostname

if [ -e "$chroot/etc/network/interfaces" ]; then # ubuntu
  cat >> $chroot/etc/network/interfaces <<EOS
auto lo
iface lo inet loopback
EOS

elif [ -e "$chroot/etc/sysconfig/network" ]; then # centos
  cat >> $chroot/etc/sysconfig/network <<EOS
NETWORKING=yes
NETWORKING_IPV6=no
HOSTNAME=bosh-stemcell
NOZEROCONF=yes
EOS

  cat >> $chroot/etc/NetworkManager/NetworkManager.conf <<EOS
[main]
plugins=ifcfg-rh
no-auto-default=*
EOS

fi
