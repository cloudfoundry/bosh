#!/bin/sh

# mount /proc in the chroot so java works...
mount -o bind /proc $1/proc

chroot $1 /var/vcap/bosh/src/prepare_instance.sh

chroot $1 /var/vcap/bosh/src/compile.sh
rm $1/var/vcap/bosh/src/compile.sh
umount $1/proc

cp $1/var/vcap/bosh/micro_dpkg_l.out micro_dpkg_l.out
