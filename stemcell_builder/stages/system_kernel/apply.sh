#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

if [ $DISTRIB_CODENAME == "lucid" ]
then
  variant="lts-backport-oneiric"

  # Headers are needed for open-vm-tools
  pkg_mgr install linux-image-virtual-${variant} linux-headers-virtual-${variant}
else
  pkg_mgr install linux-image-virtual
fi
