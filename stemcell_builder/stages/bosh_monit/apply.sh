#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

monit_basename=monit-5.2.5
monit_archive=$monit_basename.tar.gz

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/$monit_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
cd src
tar zxvf $monit_archive
cd $monit_basename
./configure --prefix=$bosh_dir --without-ssl
make -j4 && make install
"

mkdir -p $chroot/$bosh_dir/etc
cp $dir/assets/monitrc $chroot/$bosh_dir/etc/monitrc
chmod 0700 $chroot/$bosh_dir/etc/monitrc

# monit refuses to start without an include file present
mkdir -p $chroot/$bosh_app_dir/monit
touch $chroot/$bosh_app_dir/monit/empty.monitrc
