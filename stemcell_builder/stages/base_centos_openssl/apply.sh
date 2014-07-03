#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

dependencies="perl-WWW-Curl"
archive=openssl-devel-1.0.1h-1.x86_64.rpm

cp $dir/assets/$archive $chroot/tmp/

run_in_chroot $chroot "
yum -y install $dependencies
rpm -i /tmp/$archive --force
rm -f /tmp/$archive
"
