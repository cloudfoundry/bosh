#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

tmpfile=`mktemp`

echo "Creating base stemcell archive at $tmpfile"
tar -C $chroot -czf $tmpfile .

echo "Storing stemcell archive in chroot at $chroot/var/vcap/stemcell_base.tar.gz"
mkdir -p $chroot/var/vcap
mv $tmpfile $chroot/var/vcap/stemcell_base.tar.gz
chmod 0700 $chroot/var/vcap/stemcell_base.tar.gz
