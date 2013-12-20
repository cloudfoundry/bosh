#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Remove persistent device names so that eth0 comes up as eth0
rm -fr $chroot/etc/udev/rules.d/70-persistent-net.rules

# Add default network configuration
cat >> $chroot/etc/sysconfig/network <<EOS
NETWORKING=yes
NETWORKING_IPV6=no
HOSTNAME=localhost.localdomain
NOZEROCONF=yes
EOS

# Add default network interface configuration
cat >> $chroot/etc/sysconfig/network-scripts/ifcfg-eth0 <<EOS
DEVICE=eth0
BOOTPROTO=dhcp
ONBOOT=on
TYPE="Ethernet"
EOS
