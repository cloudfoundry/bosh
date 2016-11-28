#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

rm -f $work/root.vhd

# The size of the VHD for Azure must be a whole number in megabytes.
qemu-img convert -O vpc -o subformat=fixed $work/${stemcell_image_name} $work/root.vhd

pushd $work
tar zcf stemcell/image root.vhd
popd
