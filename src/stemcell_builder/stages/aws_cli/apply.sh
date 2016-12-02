#!/usr/bin/env bash
#

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

cd $assets_dir/s3cli
mv s3cli $chroot/var/vcap/bosh/bin/bosh-blobstore-s3
chmod +x $chroot/var/vcap/bosh/bin/bosh-blobstore-s3
