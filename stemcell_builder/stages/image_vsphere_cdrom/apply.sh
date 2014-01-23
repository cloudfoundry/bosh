#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

echo 'KERNEL=="sr0", SYMLINK+="bosh-cdrom"' > $chroot/etc/udev/rules.d/95-bosh-cdrom.rules
