#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash


mkdir -p $chroot/etc/sv
cp -a $dir/assets/runit/agent $chroot/etc/sv/agent
cp -a $dir/assets/runit/monit $chroot/etc/sv/monit
mkdir -p $chroot/var/vcap/monit/svlog

# runit
run_in_bosh_chroot $chroot "
chmod +x /etc/sv/agent/run /etc/sv/agent/log/run
ln -s /etc/sv/agent /etc/service/agent

chmod +x /etc/sv/monit/run /etc/sv/monit/log/run
ln -s /etc/sv/monit /etc/service/monit
"

# alerts for monit config
cp -a $dir/assets/alerts.monitrc $chroot/var/vcap/monit/alerts.monitrc

cd $assets_dir/go_agent

bin/build

mv out/bosh-agent $chroot/var/vcap/bosh/bin/
cp src/bosh-agent-rc $chroot/var/vcap/bosh/bin/
mv out/dav-cli $chroot/var/vcap/bosh/bin/bosh-blobstore-dav
chmod +x $chroot/var/vcap/bosh/bin/bosh-agent
chmod +x $chroot/var/vcap/bosh/bin/bosh-agent-rc
chmod +x $chroot/var/vcap/bosh/bin/bosh-blobstore-dav

cp src/bosh/mbus/agent.{cert,key} $chroot/var/vcap/bosh/

# setup additional permissions

run_in_chroot $chroot "
echo 'vcap' > /etc/cron.allow
echo 'vcap' > /etc/at.allow

chmod 0770 /var/lock
chown root:vcap /var/lock

chmod 0640 /etc/cron.allow
chown root:vcap /etc/cron.allow

chmod 0640 /etc/at.allow
chown root:vcap /etc/at.allow

ln -nsf data/sys /var/vcap/sys
"
