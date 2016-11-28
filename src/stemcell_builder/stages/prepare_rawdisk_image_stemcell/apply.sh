#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

pushd $work
rm -f disk.raw
ln ${stemcell_image_name} disk.raw
tar zcf stemcell/image disk.raw
popd
