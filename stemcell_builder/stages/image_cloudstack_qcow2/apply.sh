#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

qemu-img convert -O qcow2 $work/${stemcell_image_name} $work/root.qcow2
ln $work/root.qcow2 $work/root.img
