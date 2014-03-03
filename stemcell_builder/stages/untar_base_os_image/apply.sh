#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

mkdir -p $work

# the tar_base_os_image stage creates a tar ball of the full path of the chroot
# so we need to untar from root
pushd $work

tar zxf /tmp/base_os_image.tgz

popd
