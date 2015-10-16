#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

packages="python python-pyasn1"
pkg_mgr install $packages

wala_release=2.0.14
run_in_chroot $chroot "
  curl -L https://raw.githubusercontent.com/Azure/WALinuxAgent/WALinuxAgent-${wala_release}/waagent > /tmp/waagent
  chmod 0755 /tmp/waagent
  cp -a /tmp/waagent /usr/sbin/waagent
"

cp -f $dir/assets/etc/waagent.conf $chroot/etc/waagent.conf

cp -a $dir/assets/runit/waagent $chroot/etc/sv/waagent

# Set up waagent with runit
run_in_chroot $chroot "
chmod +x /etc/sv/waagent/run
ln -s /etc/sv/waagent /etc/service/waagent
"

cat > $chroot/etc/logrotate.d/waagent <<EOS
/var/log/waagent.log {
    monthly
    rotate 6
    notifempty
    missingok
}
EOS
