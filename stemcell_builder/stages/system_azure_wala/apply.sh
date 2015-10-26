#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

packages="python python-pyasn1"
pkg_mgr install $packages

wala_release=2.0.14
wala_expected_sha1=373f5decdf9281c90be650f32dd1f283a5f6b045

curl -L https://raw.githubusercontent.com/Azure/WALinuxAgent/WALinuxAgent-${wala_release}/waagent > /tmp/waagent
sha1=$(cat /tmp/waagent | openssl dgst -sha1  | awk 'BEGIN {FS="="}; {gsub(/ /,"",$2); print $2}')
if [ "${sha1}" != "${wala_expected_sha1}" ]; then
  echo "SHA1 of downloaded WALinuxAgent-${wala_release} ${sha1} does not match expected SHA1 ${wala_expected_sha1}."
  rm -f /tmp/waagent
  exit 1
fi

mv -f /tmp/waagent $chroot/usr/sbin/waagent

run_in_chroot $chroot "
  chmod 0755 /usr/sbin/waagent
"

cp -f $dir/assets/etc/waagent.conf $chroot/etc/waagent.conf

cp -a $dir/assets/runit/waagent $chroot/etc/sv/waagent

# Set up waagent with runit
run_in_chroot $chroot "
chmod +x /etc/sv/waagent/run
ln -s /etc/sv/waagent /etc/service/waagent
"

cat > $chroot/etc/logrotate.d/waagent <<EOS
/var/log/waagent.log {
    monthly
    rotate 6
    notifempty
    missingok
}
EOS
