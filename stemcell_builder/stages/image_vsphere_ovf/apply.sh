#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

mkdir -p $work/stemcell

pushd $work/vsphere
$image_vsphere_ovf_ovftool_path *.vmx image.ovf

# ovftool 3 introduces a bug, which we need to correct, or it won't load in vSphere
sed 's/useGlobal/manual/' -i image.ovf

popd
