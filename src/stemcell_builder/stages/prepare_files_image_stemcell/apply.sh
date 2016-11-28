#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# This only applies for warden container
chmod 1777 $chroot/tmp

pushd $chroot
tar zcvf $work/stemcell/image .
popd
