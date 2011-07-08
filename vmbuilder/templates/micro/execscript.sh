#!/bin/sh

chroot $1 /var/vcap/bosh/src/prepare_instance.sh
tar cf /tmp/chroot.tar $1

# mount /proc in the chroot so java works...
mount -o bind /proc $1/proc
chroot $1 /var/vcap/bosh/src/compile.sh
umount $1/proc

#tar cf /tmp/chroot2.tar $1
cp $1/var/vcap/bosh/micro_dpkg_l.out micro_dpkg_l.out
