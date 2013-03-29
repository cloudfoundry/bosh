#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

cp $assets_dir/dhclient.conf $chroot/etc/dhcp3/dhclient.conf
cat >> $chroot/etc/dhcp3/dhclient-enter-hooks.d/nodnsupdate <<EOS
#!/bin/sh
make_resolv_conf(){
	:
}
EOS

chmod +x $chroot/etc/dhcp3/dhclient-enter-hooks.d/nodnsupdate

cat >> $chroot/etc/network/interfaces <<EOS
auto eth0
iface eth0 inet dhcp
EOS
