#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# setup sudoers to use includedir, and make sure we don't break anything
cp -p $chroot/etc/sudoers $chroot/etc/sudoers.save
echo '#includedir /etc/sudoers.d' >> $chroot/etc/sudoers
run_in_bosh_chroot $chroot "visudo -c"
if [ $? -ne 0 ]; then
  echo "ERROR: bad sudoers file"
  exit 1
fi
rm $chroot/etc/sudoers.save
