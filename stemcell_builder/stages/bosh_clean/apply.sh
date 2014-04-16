#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# Clear src directory
rm -vrf $chroot/$bosh_dir/src

rm -vrf $chroot/tmp/*

# ubuntu trusty+ needs /etc/resolv.conf to be a symlink, so delete contents
# instead of removing the file to preserve the link
cat /dev/null > $chroot/etc/resolv.conf
