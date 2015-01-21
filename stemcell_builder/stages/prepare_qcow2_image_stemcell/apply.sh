#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

qemu-img convert -c -O qcow2 -o compat=0.10 $work/${stemcell_image_name} $work/root.qcow2

pushd $work
rm -f root.img
ln root.qcow2 root.img
tar zcf stemcell/image root.img
popd
