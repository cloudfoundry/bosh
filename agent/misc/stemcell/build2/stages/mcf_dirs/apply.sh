#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source ${base_dir}/lib/prelude_apply.bash
source ${base_dir}/lib/prelude_bosh.bash

apt_get install dnsmasq nfs-kernel-server

micro_src=${HOME}/micro
micro_dest=${bosh_app_dir}/micro
shared_dir=${bosh_app_dir}/shared

cp --archive --recursive ${micro_src}/micro/* ${chroot}/${micro_dest}

cp --archive ${dir}/assets/console.sh ${chroot}/etc/init.d

cp --archive ${dir}/assets/settings.json ${chroot}/${bosh_dir}

cp --archive ${dir}/assets/tty1.conf ${chroot}/etc/init/

mkdir ${chroot}/${shared_dir}

run_in_bosh_chroot ${chroot} "
chown vcap:vcap ${micro_dest}
chmod 755 ${micro_dest}

chmod 755 /etc/init.d/console.sh
ln --symbolic /etc/init.d/console.sh /etc/rc2.d/S10console

chown vcap:vcap ${shared_dir}
chmod 700 ${shared_dir}

cd ${micro_dest}
bundle install --path ${bosh_dir}/gems --without test

mkdir /cfsnapshot
chmod 777 /cfsnapshot
echo '/cfsnapshot 127.0.0.1(rw,sync)' >> /etc/exports
"
