#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

mkdir -p $chroot/$bosh_dir/src

# ntpd
ntpd_basename=ntp-4.2.8p4
ntpd_archive=$ntpd_basename.tgz

cp -r $dir/assets/$ntpd_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
cd src
tar zxvf $ntpd_archive
cd $ntpd_basename
./configure --prefix=/usr
make -j4 && make install

groupadd -f ntp
id -u ntp &>/dev/null || useradd -g ntp ntp
"

# config ntpd as a auto-start service
cp $dir/assets/ntp.conf $chroot/etc

# OS Specifics
if [ "$(get_os_type)" == "centos" -o "$(get_os_type)" == "rhel" -o "$(get_os_type)" == "photon" ]; then
  systemctl disable chronyd
  cp $dir/assets/ntp.service $chroot/usr/lib/systemd/system
  run_in_bosh_chroot $chroot "
  cd /usr/lib/systemd/system
  chkconfig ntp on
  "
elif [ "$(get_os_type)" == "ubuntu" ]; then
  cp $dir/assets/ntp $chroot/etc/init.d
  run_in_bosh_chroot $chroot "update-rc.d ntp defaults"
else
  echo "Unknown OS type $(get_os_type)"
  exit 1
fi
