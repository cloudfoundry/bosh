#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# Add configuration files
cp $assets_dir/rsyslog.conf $chroot/etc/rsyslog.conf

# configure upstart to start rsyslog if its config dir exists
if [ -d $chroot/etc/init ]; then
  cp $assets_dir/rsyslog_upstart.conf $chroot/etc/init/rsyslog.conf
fi

cp $assets_dir/rsyslog_logrotate.conf $chroot/etc/logrotate.d/rsyslog

# erase default rsyslog.d contents in case it was populated by an OS package;
# create the dir in case we're using the custom-built local installation
if [ -d $chroot/etc/rsyslog.d ]; then
  rm -rf $chroot/etc/rsyslog.d/*
else
  mkdir -p $chroot/etc/rsyslog.d
fi

if [ -f $chroot/etc/debian_version ]; then
  cp $assets_dir/enable-kernel-logging.conf $chroot/etc/rsyslog.d/enable-kernel-logging.conf
fi

cp -f $assets_dir/rsyslog_50-default.conf $chroot/etc/rsyslog.d/50-default.conf

# Add user/group
# add syslog to the vcap group in a separate step in case the syslog user already exists
run_in_bosh_chroot $chroot "
  useradd --system --user-group --no-create-home syslog || true
  usermod -G vcap syslog
"

# Configure /var/log directory
filenames=( auth.log daemon.log debug kern.log lpr.log mail.err mail.info \
              mail.log mail.warn messages syslog user.log )

for filename in ${filenames[@]}
do
  fullpath=/var/log/$filename
  run_in_bosh_chroot $chroot "
    touch ${fullpath} && chown syslog:adm ${fullpath} && chmod 640 ${fullpath}
  "
done

# init.d configuration is different for each OS
if [ -f $chroot/etc/debian_version ] # Ubuntu
then
  run_in_bosh_chroot $chroot "
    ln -sf /lib/init/upstart-job /etc/init.d/rsyslog
    update-rc.d rsyslog defaults
  "
elif [ -f $chroot/etc/redhat-release ] # Centos or RHEL
then
  cp $assets_dir/centos_init_d $chroot/etc/init.d/rsyslog
  run_in_bosh_chroot $chroot "
    chmod 0755 /etc/init.d/rsyslog
    chkconfig --add rsyslog
  "
else
  echo "Unknown OS, exiting"
  exit 2
fi
