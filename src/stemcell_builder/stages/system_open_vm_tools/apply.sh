#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# Installation on CentOS requires v7
pkg_mgr install open-vm-tools

# open-vm-tools installs unwanted fusermount binary
run_in_chroot $chroot "rm -f /usr/bin/fusermount"

# The above installation adds a PAM configuration with 'nullok' values in it.
# We need to get rid of those as per stig V-38497.
sed -i -r 's/\bnullok[^ ]*//g' $chroot/etc/pam.d/vmtoolsd
