#!/usr/bin/env bash
#

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash


# libestr
libestr_basename=libestr-0.1.8
libestr_archive=$libestr_basename.tar.gz

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/$libestr_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
cd src
tar zxvf $libestr_archive
cd $libestr_basename
./configure
make && make install
"

# json-c
jsonc_basename=json-c-0.11
jsonc_archive=$jsonc_basename.tar.gz

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/$jsonc_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
cd src
tar zxvf $jsonc_archive
cd $jsonc_basename
./configure
make && make install
"

# librelp
librelp_basename=librelp-1.2.0
librelp_archive=$librelp_basename.tar.gz

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/$librelp_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
cd src
tar zxvf $librelp_archive
cd $librelp_basename
./configure
make && make install
"

# Rsyslog
rsyslog_basename=rsyslog-7.4.5
rsyslog_archive=$rsyslog_basename.tar.gz

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/$rsyslog_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
cd src
tar zxvf $rsyslog_archive
cd $rsyslog_basename
./configure --enable-relp
make && make install
"

# Configure Rsyslog
cp $assets_dir/rsyslog.conf $chroot/etc/rsyslog.conf
cp $assets_dir/rsyslog_upstart.conf $chroot/etc/init/rsyslog.conf

run_in_bosh_chroot $chroot "
ln -s /lib/init/upstart-job /etc/init.d/rsyslog
update-rc.d rsyslog defaults
"