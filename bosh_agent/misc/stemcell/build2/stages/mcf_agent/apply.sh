#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

cp -aL $bosh_src_root $chroot/$bosh_dir
chown vcap:vcap $chroot/$bosh_dir

cp -a $dir/assets/runit/agent $chroot/etc/sv/agent
chmod +x $chroot/etc/sv/agent/run
chmod +x $chroot/etc/sv/agent/log/run

run_in_bosh_chroot $chroot "
gem update --system
cd bosh
apt-get --assume-yes install git-core libpq-dev libsqlite3-dev
bundle install --path $bosh_dir/gems --without development test
chmod +x bosh_agent/bin/bosh_agent
ln -s /etc/sv/agent /etc/service/agent
"

cp $dir/assets/empty_state.yml $chroot/$bosh_dir/state.yml

# the bosh agent installs a config that rotates on size
mv $chroot/etc/cron.daily/logrotate $chroot/etc/cron.hourly/logrotate
