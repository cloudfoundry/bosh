#!/bin/sh
#
# Copyright (c) 2009-2012 VMware, Inc.

chroot $1 /var/vcap/bosh/src/prepare_instance.sh
cp $1/var/vcap/bosh/stemcell_dpkg_l.out stemcell_dpkg_l.out
