#!/usr/bin/env bash

set -e
set -x

cd /usr/src
tar zxvf vmware-tools-vmxnet3-modules.tar.gz
cd modules/vmware-tools-vmxnet3-modules/vmxnet3-only

module_dir=`ls -d /lib/modules/2.6.*-virtual | tail -1`
kernel_uname_r=`basename ${module_dir}`

# Work around Makefile autodetection of environment - kernel version mismatch
# as the chroot reports the host OS version
sed "s/^VM_UNAME.*$/VM_UNAME = ${kernel_uname_r}/" Makefile > Makefile.vmxnet3_bosh

install_dir="${module_dir}/updates/vmxnet3"
mkdir -p $install_dir

make -j4 -f Makefile.vmxnet3_bosh
cp vmxnet3.ko $install_dir/
