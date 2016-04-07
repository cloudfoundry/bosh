#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

pkg_mgr install auditd

echo '
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=[ARCH] -S init_module -S delete_module -k modules' >> $chroot/etc/audit/audit.rules

sed -i 's/disk_error_action = .*$/disk_error_action = SYSLOG/g' $chroot/etc/audit/auditd.conf

chmod 0655 $chroot/etc/audit/
chmod 0644 $chroot/etc/audit/audit.rules
chmod 0644 $chroot/etc/audit/auditd.conf
