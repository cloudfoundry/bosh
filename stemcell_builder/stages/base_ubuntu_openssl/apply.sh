#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

cp $dir/assets/*.deb $chroot/tmp/

# libssl-dev package was built from openssl source with checkinstall
# openssl is a dummy package that was genearated by equivs
# and is installed to satisfy dependency of other packages

run_in_chroot $chroot "
dpkg --force-overwrite -i /tmp/libssl-dev_1.0.1h-1_amd64.deb
dpkg -i /tmp/openssl_1.0.1h_all.deb
rm -f /tmp/*.deb
"
