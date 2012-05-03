#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

debs="scsitools tshark mg htop module-assistant debhelper runit"

# Install packages
run_in_chroot $chroot "apt-get update"
run_in_chroot $chroot "apt-get install -y --force-yes --no-install-recommends $debs"
run_in_chroot $chroot "apt-get clean"
