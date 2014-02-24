#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

mkdir -p $chroot/$bosh_dir/src

# Libyaml
yaml_basename=yaml-0.1.5
yaml_archive=$yaml_basename.tar.gz

# hide libyaml here temporarily until we figure out how to remove the runtime dependency altogether
mkdir -p $chroot/$bosh_dir/deps/$yaml_basename
cp -r $dir/assets/$yaml_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
cd src
tar zxvf $yaml_archive
cd $yaml_basename
CFLAGS='-fPIC' ./configure --prefix=$bosh_dir/deps/$yaml_basename --disable-shared
make && make install
"

# Ruby
ruby_basename=ruby-1.9.3-p484
ruby_archive=$ruby_basename.tar.gz

cp -r $dir/assets/$ruby_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
cd src
tar zxvf $ruby_archive
cd $ruby_basename
sed -i 's/\\(OSSL_SSL_METHOD_ENTRY(SSLv2[^3]\\)/\\/\\/\\1/g' ./ext/openssl/ossl_ssl.c
LDFLAGS='-Wl,-rpath -Wl,$bosh_dir/deps/$yaml_basename' CFLAGS='-fPIC' ./configure --prefix=$bosh_dir --disable-install-doc --with-opt-dir=$bosh_dir/deps/$yaml_basename
make -j4 && make install
"

# RubyGems
rubygems_basename=rubygems-1.8.24
rubygems_archive=$rubygems_basename.tgz

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/$rubygems_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
cd src
tar zxvf $rubygems_archive
cd $rubygems_basename

# This fails, but apparently does work for 1.3.7
$bosh_dir/bin/ruby setup.rb || true
"

# Skip gem docs
mkdir -p $chroot/var/vcap/bosh/etc
echo "gem: --local --no-rdoc --no-ri" >> $chroot/var/vcap/bosh/etc/gemrc

# Bundler
bundler_gem=bundler-1.2.3.gem

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/$bundler_gem $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
cd src
gem install $bundler_gem --local --no-ri --no-rdoc
"

# Clean up libyaml
rm -rf /$bosh_dir/src
