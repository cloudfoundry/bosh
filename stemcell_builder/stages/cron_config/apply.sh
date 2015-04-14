#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

grep -v RANDOM_DELAY $chroot/etc/anacrontab > $chroot/etc/anacrontab.new
echo "" >> $chroot/etc/anacrontab.new
echo RANDOM_DELAY=60 >> $chroot/etc/anacrontab.new
mv $chroot/etc/anacrontab.new $chroot/etc/anacrontab


# rebuilding the man-db is a costly operation the first time it's run
# and it doesn't really need to run again as long as we're not installing
# new software into the system. so we run it it during the stemcell build,
# and then make sure it never runs again

# Red Hat flavored systems
if [ -x $chroot/etc/cron.daily/man-db ]; then
  $chroot/etc/cron.daily/man-db
fi

# Ubuntu
if [ -x $chroot/etc/cron.daily/man-db.cron ]; then
  $chroot/etc/cron.daily/man-db.cron
fi

rm -f \
  $chroot/etc/cron.weekly/man-db \
  $chroot/etc/cron.daily/man-db \
  $chroot/etc/cron.daily/man-db.cron


if [ -d $chroot/etc/apt/apt.conf.d ]; then
cat >> $chroot/etc/apt/apt.conf.d/02periodic <<EOF
APT::Periodic {
  Enable "0";
}
EOF
fi
