#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# TODO: We really want to lock these down - but we're having issues
# with both our components and users apps assuming this is writable
# Tempfile and friends - we'll punt on this for 4/12 and revisit it
# in the immediate release cycle after that.
# Lock dowon /tmp and /var/tmp - jobs should use /var/vcap/data/tmp
chmod 0770 $chroot/tmp $chroot/var/tmp

# remove setuid binaries - except su/sudo (sudoedit is hardlinked)
run_in_bosh_chroot $chroot "
find / -xdev -perm +6000 -a -type f \
  -a -not \( -name sudo -o -name su -o -name sudoedit \) \
  -exec chmod ug-s {} \;
"
