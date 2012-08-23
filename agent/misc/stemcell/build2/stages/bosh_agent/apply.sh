#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

agent_dir=$bosh_dir/agent_${bosh_agent_src_version}_builtin

mkdir -p $chroot/$agent_dir
cp -aL $bosh_agent_src_dir/{bin,lib,vendor,Gemfile*} $chroot/$agent_dir

# Link agent
run_in_bosh_chroot $chroot "
ln -s $agent_dir agent
chmod +x agent/bin/agent
"

# Install gems
run_in_bosh_chroot $chroot "
cd agent
bundle install --path $bosh_dir/gems --without development test
"

cp -a $dir/assets/runit/agent $chroot/etc/sv/agent

# runit
run_in_bosh_chroot $chroot "
chmod +x /etc/sv/agent/run /etc/sv/agent/log/run
ln -s /etc/sv/agent /etc/service/agent
"

cp $dir/assets/empty_state.yml $chroot/$bosh_dir/state.yml

# the bosh agent installs a config that rotates on size
mv $chroot/etc/cron.daily/logrotate $chroot/etc/cron.hourly/logrotate
