#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

os_type=$(get_os_type)

if [ "${os_type}" == "centos" ] ; then
    pkg_mgr install audit
    run_in_bosh_chroot $chroot "systemctl enable auditd.service"
fi

if [ "${os_type}" == "ubuntu" ] ; then
    pkg_mgr install auditd

    # Without this, auditd will read from /etc/audit/audit.rules instead
    # of /etc/audit/rules.d/*.
    sed -i 's/^USE_AUGENRULES="[Nn][Oo]"$/USE_AUGENRULES="yes"/' $chroot/etc/default/auditd

    cp $assets_dir/auditd_upstart.conf $chroot/etc/init/auditd.conf
fi

if [ "${os_type}" == "centos" ] || [ "${os_type}" == "ubuntu" ] ; then
    echo '
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules' >> $chroot/etc/audit/rules.d/audit.rules

    sed -i 's/disk_error_action = .*$/disk_error_action = SYSLOG/g' $chroot/etc/audit/auditd.conf
    sed -i 's/disk_full_action = .*$/disk_full_action = SYSLOG/g' $chroot/etc/audit/auditd.conf
    sed -i 's/admin_space_left_action = .*$/admin_space_left_action = SYSLOG/g' $chroot/etc/audit/auditd.conf
    sed -i 's/space_left_action = .*$/space_left_action = SYSLOG/g' $chroot/etc/audit/auditd.conf
    sed -i 's/num_logs = .*$/num_logs = 5/g' $chroot/etc/audit/auditd.conf
    sed -i 's/max_log_file = .*$/max_log_file = 6/g' $chroot/etc/audit/auditd.conf
    sed -i 's/max_log_file_action = .*$/max_log_file_action = ROTATE/g' $chroot/etc/audit/auditd.conf
fi
