#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# The logrotate.conf supplied by the default image is about to be stomped.
# Make sure it hasn't changed. If it has changed, the contents of the new file should
# evaluated to see if the replacement file should be updated.
if [ "$(get_os_type)" == "centos" ]; then
  echo "3129afc4edd2483030c6be7e7e7e1a7bfb3f110a  $chroot/etc/logrotate.conf" | sha1sum -c
  cp $assets_dir/centos-logrotate.conf $chroot/etc/logrotate.conf
elif [ "$(get_os_type)" == "ubuntu" ]; then
  echo "7e52df7373b42a36b2bdde9bc88315e828cdc61e  $chroot/etc/logrotate.conf" | sha1sum -c
  cp $assets_dir/ubuntu-logrotate.conf $chroot/etc/logrotate.conf
fi

mv $chroot/etc/cron.daily/logrotate $chroot/usr/bin/logrotate-cron
echo '0,15,30,45 * * * * root /usr/bin/logrotate-cron' > $chroot/etc/cron.d/logrotate

cp -f $assets_dir/default_su_directive $chroot/etc/logrotate.d/default_su_directive
