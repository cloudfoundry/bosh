#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# the tar_base_os_image stage creates a tar ball of the chroot with no enclosing directory
tar zxf $os_image_tgz -C $chroot

cp /etc/resolv.conf $chroot/etc/resolv.conf
