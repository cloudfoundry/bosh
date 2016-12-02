#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

pushd $work/ovf
$image_ovftool_path *.vmx image.ovf

# ovftool 3 introduces a bug, which we need to correct, or it won't load in vSphere
OLD_OVF_SHA=$(sha1sum image.ovf | cut -d ' ' -f 1)
sed 's/useGlobal/manual/' -i image.ovf
NEW_OVF_SHA=$(sha1sum image.ovf | cut -d ' ' -f 1)
sed "s/$OLD_OVF_SHA/$NEW_OVF_SHA/" -i image.mf

popd
