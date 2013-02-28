#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

agent_dir=$bosh_dir/bosh_agent_${bosh_agent_src_version}_builtin

mkdir -p $chroot/$agent_dir
cp -aL $assets_dir/gems $chroot/$agent_dir

# Link agent
run_in_bosh_chroot $chroot "
ln -s $agent_dir agent
"

# Install gems
run_in_bosh_chroot $chroot "
cd agent/gems
gem install bosh_agent --no-rdoc --no-ri -l
"

cp -a $dir/assets/runit/agent $chroot/etc/sv/agent

if [ ${mcf_enabled:-no} == "yes" ]; then
  mv $chroot/etc/sv/agent/mcf_run $chroot/etc/sv/agent/run
else
  rm $chroot/etc/sv/agent/mcf_run
fi

# runit
run_in_bosh_chroot $chroot "
chmod +x /etc/sv/agent/run /etc/sv/agent/log/run
ln -s /etc/sv/agent /etc/service/agent
"

cp $dir/assets/empty_state.yml $chroot/$bosh_dir/state.yml

# the bosh agent installs a config that rotates on size
mv $chroot/etc/cron.daily/logrotate $chroot/etc/cron.hourly/logrotate
