#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

cp $assets_dir/etc/rc.local $chroot/etc/rc.local
cp $assets_dir/root/firstboot.sh $chroot/root/firstboot.sh
chmod 0755 $chroot/root/firstboot.sh