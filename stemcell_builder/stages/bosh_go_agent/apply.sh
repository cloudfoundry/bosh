#!/usr/bin/env bash

set -e
base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

mkdir -p $chroot/etc/sv
cp -a $dir/assets/runit/agent $chroot/etc/sv/agent
cp -a $dir/assets/runit/monit $chroot/etc/sv/monit
mkdir -p $chroot/var/vcap/monit/svlog

# Set up agent and monit with runit
run_in_bosh_chroot $chroot "
chmod +x /etc/sv/agent/run /etc/sv/agent/log/run
rm -f /etc/service/agent
ln -s /etc/sv/agent /etc/service/agent

chmod +x /etc/sv/monit/run /etc/sv/monit/log/run
rm -f /etc/service/monit
ln -s /etc/sv/monit /etc/service/monit
"

# Alerts for monit config
cp -a $dir/assets/alerts.monitrc $chroot/var/vcap/monit/alerts.monitrc

agent_dir=$assets_dir/go/src/github.com/cloudfoundry/bosh-agent

cd $agent_dir
bin/build
mv out/bosh-agent $chroot/var/vcap/bosh/bin/
cp Tools/bosh-agent-rc $chroot/var/vcap/bosh/bin/
cp mbus/agent.{cert,key} $chroot/var/vcap/bosh/

cd $assets_dir/go/src/github.com/cloudfoundry/bosh-davcli
bin/build
mv out/dav-cli $chroot/var/vcap/bosh/bin/bosh-blobstore-dav

chmod +x $chroot/var/vcap/bosh/bin/bosh-agent
chmod +x $chroot/var/vcap/bosh/bin/bosh-agent-rc
chmod +x $chroot/var/vcap/bosh/bin/bosh-blobstore-dav

# Setup additional permissions
run_in_chroot $chroot "
echo 'vcap' > /etc/cron.allow
echo 'vcap' > /etc/at.allow

chmod 0770 /var/lock
chown -h root:vcap /var/lock
chown -LR root:vcap /var/lock

chmod 0640 /etc/cron.allow
chown root:vcap /etc/cron.allow

chmod 0640 /etc/at.allow
chown root:vcap /etc/at.allow
"

# Since go agent is always specified with -C provide empty conf.
# File will be overwritten in whole by infrastructures.
echo '{}' > $chroot/var/vcap/bosh/agent.json

# We need to capture ssh events
cp $dir/assets/rsyslog.d/10-auth_agent_forwarder.conf $chroot/etc/rsyslog.d/10-auth_agent_forwarder.conf
