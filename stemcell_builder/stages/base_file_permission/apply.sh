#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

chmod 0000 $chroot/etc/gshadow
chown root:root $chroot/etc/gshadow

chmod 0000 $chroot/etc/shadow
chown root:root $chroot/etc/shadow

# only for CentOS
chmod 0755 $chroot/lib
chmod 0755 $chroot/lib64
