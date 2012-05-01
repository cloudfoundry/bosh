#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

kernel="lts-backport-natty"

run_in_chroot $chroot "apt-get update"
run_in_chroot $chroot "apt-get install -y --force-yes --no-install-recommends linux-image-virtual-${kernel} linux-headers-virtual-${kernel}"
run_in_chroot $chroot "apt-get clean"
