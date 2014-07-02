#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

basename=openssl-1.0.1h
archive=$basename.tar.gz

cp -r $dir/assets/$archive $chroot/tmp/

run_in_bosh_chroot $chroot "
cd /tmp
tar zxvf $archive --no-same-owner --no-same-permissions
cd $basename
./config --prefix=/usr
# OpenSSL does not support parallel builds, so make without -j4
make && make install
"
