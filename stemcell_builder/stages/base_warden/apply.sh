#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Explicit make the mount point for bind-mount
# Otherwise using none ubuntu host will fail creating vm
mkdir -p $chroot/warden-cpi-dev

# Install lucid kernel patch for Warden in Warden
apt_get install linux-image-generic-lts-backport-natty

# This is a Hacky way to force Warden in Warden to use overlayfs for now
sed -i s/lucid/precise/ $chroot/etc/lsb-release