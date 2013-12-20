#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# we have to make this script work on both debian and redhat based systems
# as it is requried for initial network configuration on AWS and OpenStack
if [ -e "$chroot/etc/network/interfaces" ]
then

cat >> $chroot/etc/network/interfaces <<EOS
auto eth0
iface eth0 inet dhcp
EOS

elif [ -e "$chroot/etc/sysconfig/network" ]
then

cat >> $chroot/etc/sysconfig/network <<EOS
NETWORKING=yes
NETWORKING_IPV6=no
HOSTNAME=localhost.localdomain
NOZEROCONF=yes
EOS

cat >> $chroot/etc/sysconfig/network-scripts/ifcfg-eth0 <<EOS
DEVICE=eth0
BOOTPROTO=dhcp
ONBOOT=on
TYPE="Ethernet"
EOS

fi