#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# Clear src directory
rm -rf $chroot/$bosh_dir/src

# Clear caches
run_in_bosh_chroot $chroot "apt-get clean"
