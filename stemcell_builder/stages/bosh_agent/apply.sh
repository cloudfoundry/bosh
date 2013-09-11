#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

if [ -z "${agent_gem_src_url:-}" ]; then
  agent_dir=$bosh_dir/agent
  mkdir -p $chroot/$agent_dir
  cp -aL $assets_dir/gems $chroot/$agent_dir
  # Install gems from local src
  run_in_bosh_chroot $chroot "
  cd agent/gems
  gem install bosh_agent --no-rdoc --no-ri -l
  "
  rm -rf $chroot/$agent_dir
else
  # Install gems from CI pipeline bucket
  run_in_bosh_chroot $chroot "
    gem install bosh_agent --no-rdoc --no-ri -r --pre --source ${agent_gem_src_url}
    "
fi

mkdir -p $chroot/etc/sv
cp -a $dir/assets/runit/agent $chroot/etc/sv/agent

# runit
run_in_bosh_chroot $chroot "
chmod +x /etc/sv/agent/run /etc/sv/agent/log/run
ln -s /etc/sv/agent /etc/service/agent
"

cp $dir/assets/empty_state.yml $chroot/$bosh_dir/state.yml

# the bosh agent installs a config that rotates on size
mv $chroot/etc/cron.daily/logrotate $chroot/etc/cron.hourly/logrotate

# we need to capture ssh events
cp $dir/assets/rsyslog.d/10-auth_agent_forwarder.conf $chroot/etc/rsyslog.d/10-auth_agent_forwarder.conf
