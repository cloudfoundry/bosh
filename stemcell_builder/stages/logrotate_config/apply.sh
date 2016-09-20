#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

mv $chroot/etc/cron.daily/logrotate $chroot/usr/bin/logrotate-cron
echo '0,15,30,45 * * * * root /usr/bin/logrotate-cron' > $chroot/etc/cron.d/logrotate

cp -f $assets_dir/default_su_directive $chroot/etc/logrotate.d/default_su_directive
