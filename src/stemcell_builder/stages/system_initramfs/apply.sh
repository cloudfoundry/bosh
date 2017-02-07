#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

export KERNEL=`ls ${chroot}/boot/initramfs* | sed -e "s/^.*\/initramfs-//; s/.img//"`

run_in_chroot $chroot "dracut --force --add-drivers 'ext4 scsi_transport_spi mptbase mptscsih mptspi xen-blkfront' --kver ${KERNEL}"
