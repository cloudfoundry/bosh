#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

echo '# prevent bluetooth module to be loaded
install bluetooth /bin/true' >> $chroot/etc/modprobe.d/blacklist.conf