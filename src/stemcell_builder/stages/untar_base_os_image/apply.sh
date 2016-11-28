#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# the tar_base_os_image stage creates a tar ball of the chroot with no enclosing directory
tar zxf $os_image_tgz -C $chroot

# ubuntu trusty+ needs /etc/resolv.conf to be a symlink, so overwrite the file
# instead of copying it to preserve the link
cat /etc/resolv.conf > $chroot/etc/resolv.conf
