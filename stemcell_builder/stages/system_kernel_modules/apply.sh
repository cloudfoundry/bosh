#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

echo '# prevent blacklisted modules from being loaded
install bluetooth /bin/true
install tipc /bin/true
install sctp /bin/true
install dccp /bin/true' >> $chroot/etc/modprobe.d/blacklist.conf
