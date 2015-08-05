#!/usr/bin/env bash
#

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

cd $assets_dir/s3cli
if [ "`uname -m`" == "ppc64le" ]; then
  # assume gccgo is installed in /usr/local/gccgo in ppc64ke
  export PATH=/usr/local/gccgo/bin:$PATH
  export LD_LIBRARY_PATH=/usr/local/gccgo/lib64
fi
bin/build

mv out/s3 $chroot/var/vcap/bosh/bin/bosh-blobstore-s3
chmod +x $chroot/var/vcap/bosh/bin/bosh-blobstore-s3
