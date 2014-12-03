#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Turn-off reverse DNS resolution in sshd
sed "/^ *UseDNS/d" -i $chroot/etc/ssh/sshd_config
echo 'UseDNS no' >> $chroot/etc/ssh/sshd_config
