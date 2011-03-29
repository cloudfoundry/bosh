#!/bin/sh
chroot $1 /var/vcap/bosh/src/prepare_instance.sh
cp $1/var/vcap/bosh/stemcell_dpkg_l.out stemcell_dpkg_l.out
