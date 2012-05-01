#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Verify that parted is available
if ! which parted >/dev/null
then
  echo "parted is not available"
  exit 1
fi

# Verify that kpartx is available
if ! which kpartx >/dev/null
then
  echo "kpartx is not available"
  exit 1
fi

if [ -z "${image_create_disk_size:-}" ]
then
  image_create_disk_size=1225
fi

persist_value image_create_disk_size
