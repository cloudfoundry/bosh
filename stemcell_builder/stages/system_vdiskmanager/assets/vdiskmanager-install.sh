#!/usr/bin/env bash

set -e
set -x

cd /tmp
tar -xvf vdiskmanager.tar

module_dir=`ls -d /lib/modules/3.*-virtual | tail -1`
install_dir="${module_dir}/vdiskmanager"
perl vmware-vix-disklib-distrib/vmware-install.pl "$install_dir"