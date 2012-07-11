#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# setup crontab for root to use ntpdate every 15 minutes
mkdir -p $chroot/$bosh_dir/log
cp $dir/assets/ntpdate $chroot/$bosh_dir/bin/ntpdate
chmod 0755 $chroot/$bosh_dir/bin/ntpdate
echo "0,15,30,45 * * * * ${bosh_app_dir}/bosh/bin/ntpdate" > $chroot/tmp/ntpdate.cron

run_in_bosh_chroot $chroot "
crontab -u root /tmp/ntpdate.cron
"

rm $chroot/tmp/ntpdate.cron
