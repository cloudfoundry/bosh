#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

function write_shared_audit_rules {
  echo '
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules

# /sbin/insmod, /sbin/rmmod, /sbin/modprobe are symlinks to /bin/kmod
# Adding a rule for /bin/kmod because auditd does not follow symlinks
-w /bin/kmod -p x -k modules

# Adding finit_module since /bin/kmod uses finit_module
-a always,exit -F arch=b64 -S finit_module -S init_module -S delete_module -k modules

# Record events that modify system date and time
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-a always,exit -F arch=b32 -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

# Record file deletion events
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rmdir -S rename -S renameat -F auid>=500 -F auid!=4294967295 -k delete
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rmdir -S rename -S renameat -F auid>=500 -F auid!=4294967295 -k delete

# Record changes to sudoers file
-w /etc/sudoers -p wa -k scope

# Record login and logout events
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins
-w /var/run/faillock -p wa -k logins

# Record session initiation events
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session

# Record events that modify user/group information
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# Record events that modify system network environment
-a exit,always -F arch=b64 -S sethostname -S setdomainname -k system-locale
-a exit,always -F arch=b32 -S sethostname -S setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/network -p wa -k system-locale

# Record events that modify systems mandatory access controls
-w /etc/selinux/ -p wa -k MAC-policy

# Record system administrator actions
-w /var/log/sudo.log -p wa -k actions

# Record file system mounts
-a always,exit -F arch=b64 -S mount -F auid>=500 -F auid!=4294967295 -k mounts
-a always,exit -F arch=b32 -S mount -F auid>=500 -F auid!=4294967295 -k mounts

# Record discretionary access control permission modification events
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=500 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=500 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=500 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=500 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=500 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=500 -F auid!=4294967295 -k perm_mod

# Record unsuccessful unauthorized access attempts to files - EACCES
-a always,exit -F arch=b64 -S creat -S open -S open_by_handle_at -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=500 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S creat -S open -S open_by_handle_at -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=500 -F auid!=4294967295 -k access
-a always,exit -F arch=b64 -S creat -S open -S open_by_handle_at -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=500 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S creat -S open -S open_by_handle_at -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=500 -F auid!=4294967295 -k access

# Record use of additional binaries
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/sbin/unix_chkpwd -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/sbin/mount.nfs -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/sbin/pam_timestamp_check -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/bin/write -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/bin/mount -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/bin/newgrp -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/bin/wall -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/bin/passwd -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/bin/umount -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/bin/crontab -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/bin/chfn -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/bin/ssh-agent -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/bin/gpasswd -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/bin/chsh -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/bin/chage -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/bin/mount -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/bin/su -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/bin/umount -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/sbin/mount.nfs -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/sbin/netreport -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/sbin/postdrop -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/sbin/postqueue -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/sbin/usernetctl -k privileged

' >> $chroot/etc/audit/rules.d/audit.rules
}

function make_audit_rules_immutable {
      echo '
# Make audit rules immutable
-e 2' >> $chroot/etc/audit/rules.d/audit.rules
}

function override_default_audit_variables {
    sed -i 's/^disk_error_action = .*$/disk_error_action = SYSLOG/g' $chroot/etc/audit/auditd.conf
    sed -i 's/^disk_full_action = .*$/disk_full_action = SYSLOG/g' $chroot/etc/audit/auditd.conf
    sed -i 's/^admin_space_left_action = .*$/admin_space_left_action = SYSLOG/g' $chroot/etc/audit/auditd.conf
    sed -i 's/^space_left_action = .*$/space_left_action = SYSLOG/g' $chroot/etc/audit/auditd.conf
    sed -i 's/^num_logs = .*$/num_logs = 5/g' $chroot/etc/audit/auditd.conf
    sed -i 's/^max_log_file = .*$/max_log_file = 6/g' $chroot/etc/audit/auditd.conf
    sed -i 's/^max_log_file_action = .*$/max_log_file_action = ROTATE/g' $chroot/etc/audit/auditd.conf
    sed -i 's/^log_group = .*$/log_group = root/g' $chroot/etc/audit/auditd.conf
    sed -i 's/^space_left = .*$/space_left = 75/g' $chroot/etc/audit/auditd.conf
    sed -i 's/^admin_space_left = .*$/admin_space_left = 50/g' $chroot/etc/audit/auditd.conf

    sed -i 's/^active = .*$/active = yes/g' $chroot/etc/audisp/plugins.d/syslog.conf
}

function record_use_of_privileged_binaries {
    echo '
# Record use of privileged commands' >> $chroot/etc/audit/rules.d/audit.rules
    find $chroot/bin $chroot/sbin $chroot/usr/bin $chroot/usr/sbin $chroot/boot -xdev \( -perm -4000 -o -perm -2000 \) -type f | sed -e s:^${chroot}:: | awk '{print "-a always,exit -F path=" $1 " -F perm=x -F auid>=500 -F auid!=4294967295 -k privileged" }' >> $chroot/etc/audit/rules.d/audit.rules
}
