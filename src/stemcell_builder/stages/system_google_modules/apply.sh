#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

echo "acpiphp" >> $chroot/etc/modules
echo "virtio_scsi" >> $chroot/etc/modules
