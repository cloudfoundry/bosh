#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

assert_available parted
assert_available kpartx

if [ -z "${image_create_disk_size:-}" ]
then
  image_create_disk_size=1225
fi

persist_value image_create_disk_size
persist_value stemcell_image_name
