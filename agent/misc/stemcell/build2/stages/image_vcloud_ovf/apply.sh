#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

mkdir -p $work/stemcell

pushd $work/vcloud
$image_vcloud_ovf_ovftool_path *.vmx image.ovf
popd
