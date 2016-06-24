#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

chmod 0000 $chroot/etc/gshadow
chown root:root $chroot/etc/gshadow

chmod 0000 $chroot/etc/shadow
chown root:root $chroot/etc/shadow

# only for CentOS
chmod 0755 $chroot/lib
chmod 0755 $chroot/lib64

# remove setuid binaries - except su/sudo (sudoedit is hardlinked)
run_in_bosh_chroot $chroot "
find / -xdev -perm /6000 -a -type f \
  -a -not \( -name sudo -o -name su -o -name sudoedit \) \
  -exec chmod ug-s {} \;
"
