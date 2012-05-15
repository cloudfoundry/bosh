#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Verify that kpartx is available
if ! which kpartx >/dev/null
then
  echo "kpartx is not available"
  exit 1
fi
